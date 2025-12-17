import json
import logging
import os
import time
from typing import List, Optional, Dict

import motor.motor_asyncio
from bson import ObjectId
from fastapi import Body, FastAPI, HTTPException, status
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache
from logmiddleware import RouterLoggingMiddleware, logging_config
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from pydantic.functional_validators import BeforeValidator
from pymongo import errors
from redis import asyncio as aioredis
from typing_extensions import Annotated

# Configure JSON logging
logging.config.dictConfig(logging_config)
logger = logging.getLogger(__name__)

app = FastAPI()
app.add_middleware(
    RouterLoggingMiddleware,
    logger=logger,
)

DATABASE_URL = os.environ["MONGODB_URL"]
DATABASE_NAME = os.environ["MONGODB_DATABASE_NAME"]
REDIS_URL = os.getenv("REDIS_URL", None)


def nocache(*args, **kwargs):
    def decorator(func):
        return func

    return decorator


if REDIS_URL:
    cache = cache
else:
    cache = nocache


client = motor.motor_asyncio.AsyncIOMotorClient(DATABASE_URL)
db = client[DATABASE_NAME]

TARGET_COLLECTION_NAME = os.getenv("MONGODB_COLLECTION_NAME", "helloDoc")

SHARD_URIS = {
    "shard1": os.getenv(
        "SHARD1_URI",
        "mongodb://shard1a:27018,shard1b:27018/?replicaSet=shard1",
    ),
    "shard2": os.getenv(
        "SHARD2_URI",
        "mongodb://shard2a:27019,shard2b:27019/?replicaSet=shard2",
    ),
}

SHARD_CLIENTS = {
    name: motor.motor_asyncio.AsyncIOMotorClient(uri)
    for name, uri in SHARD_URIS.items()
}


async def get_replicas_per_shard() -> Dict[str, Optional[int]]:
    """Возвращает количество реплик в каждом шарде."""
    replicas: Dict[str, Optional[int]] = {}
    for shard_name, shard_client in SHARD_CLIENTS.items():
        try:
            status = await shard_client.admin.command("replSetGetStatus")
            replicas[shard_name] = len(status.get("members", []))
        except Exception as exc:
            logger.warning(
                "Failed to get replica status for %s: %s",
                shard_name,
                exc,
            )
            replicas[shard_name] = None
    return replicas


# Represents an ObjectId field in the database.
# It will be represented as a `str` on the model so that it can be serialized to JSON.
PyObjectId = Annotated[str, BeforeValidator(str)]


@app.on_event("startup")
async def startup():
    if REDIS_URL:
        redis = aioredis.from_url(REDIS_URL, encoding="utf8", decode_responses=True)
        FastAPICache.init(RedisBackend(redis), prefix="api:cache")


class UserModel(BaseModel):
    """
    Container for a single user record.
    """

    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    age: int = Field(...)
    name: str = Field(...)


class UserCollection(BaseModel):
    """
    A container holding a list of `UserModel` instances.
    """

    users: List[UserModel]



@app.get("/")
async def root():
    # 1. Коллекции и количество документов
    collection_names = await db.list_collection_names()
    collections = {}
    for collection_name in collection_names:
        collection = db.get_collection(collection_name)
        collections[collection_name] = {
            "documents_count": await collection.count_documents({})
        }

    # 2. Общее количество документов в базе
    db_total_documents = None
    try:
        db_stats = await db.command("dbstats")
        db_total_documents = db_stats.get("objects")
    except Exception as exc:
        logger.warning("Failed to get dbstats: %s", exc)

    # 3. Количество документов по шардерам для целевой коллекции
    target_collection_total_documents = None
    target_collection_shard_documents = None
    try:
        target_collection = db.get_collection(TARGET_COLLECTION_NAME)
        target_collection_total_documents = await target_collection.count_documents({})

        coll_stats = await db.command({"collStats": TARGET_COLLECTION_NAME})
        if coll_stats.get("sharded") and "shards" in coll_stats:
            target_collection_shard_documents = {
                shard_name: shard_stats.get("count", 0)
                for shard_name, shard_stats in coll_stats["shards"].items()
            }
    except Exception as exc:
        logger.warning(
            "Failed to compute per-shard stats for %s: %s",
            TARGET_COLLECTION_NAME,
            exc,
        )

    # 4. Топология кластера
    topology_description = client.topology_description
    read_preference = client.client_options.read_preference
    topology_type = topology_description.topology_type_name
    replicaset_name = topology_description.replica_set_name

    shards = None
    if topology_type == "Sharded":
        shards_list = await client.admin.command("listShards")
        shards = {}
        for shard in shards_list.get("shards", {}):
            shards[shard["_id"]] = shard["host"]

    # 5. Состояние кэша
    cache_enabled = False
    if REDIS_URL:
        cache_enabled = FastAPICache.get_enable()

    # 6. Количество реплик в каждом шарде
    replicas_per_shard = await get_replicas_per_shard()

    return {
        "mongo_topology_type": topology_type,
        "mongo_replicaset_name": replicaset_name,
        "mongo_db": DATABASE_NAME,
        "read_preference": str(read_preference),
        "mongo_nodes": client.nodes,
        "mongo_primary_host": client.primary,
        "mongo_secondary_hosts": client.secondaries,
        "mongo_is_primary": client.is_primary,
        "mongo_is_mongos": client.is_mongos,
        "collections": collections,
        "shards": shards,
        "cache_enabled": cache_enabled,
        "db_total_documents": db_total_documents,
        "target_collection": TARGET_COLLECTION_NAME,
        "target_collection_total_documents": target_collection_total_documents,
        "target_collection_shard_documents": target_collection_shard_documents,
        "replicas_per_shard": replicas_per_shard,
        "status": "OK",
    }

@app.get("/{collection_name}/count")
async def collection_count(collection_name: str):
    collection = db.get_collection(collection_name)
    items_count = await collection.count_documents({})
    # status = await client.admin.command('replSetGetStatus')
    # import ipdb; ipdb.set_trace()
    return {"status": "OK", "mongo_db": DATABASE_NAME, "items_count": items_count}


@app.get(
    "/{collection_name}/users",
    response_description="List all users",
    response_model=UserCollection,
    response_model_by_alias=False,
)
@cache(expire=60 * 1)
async def list_users(collection_name: str):
    """
    List all of the user data in the database.
    The response is unpaginated and limited to 1000 results.
    """
    time.sleep(1)
    collection = db.get_collection(collection_name)
    return UserCollection(users=await collection.find().to_list(1000))


@app.get(
    "/{collection_name}/users/{name}",
    response_description="Get a single user",
    response_model=UserModel,
    response_model_by_alias=False,
)
async def show_user(collection_name: str, name: str):
    """
    Get the record for a specific user, looked up by `name`.
    """

    collection = db.get_collection(collection_name)
    if (user := await collection.find_one({"name": name})) is not None:
        return user

    raise HTTPException(status_code=404, detail=f"User {name} not found")


@app.post(
    "/{collection_name}/users",
    response_description="Add new user",
    response_model=UserModel,
    status_code=status.HTTP_201_CREATED,
    response_model_by_alias=False,
)
async def create_user(collection_name: str, user: UserModel = Body(...)):
    """
    Insert a new user record.

    A unique `id` will be created and provided in the response.
    """
    collection = db.get_collection(collection_name)
    new_user = await collection.insert_one(
        user.model_dump(by_alias=True, exclude=["id"])
    )
    created_user = await collection.find_one({"_id": new_user.inserted_id})
    return created_user
