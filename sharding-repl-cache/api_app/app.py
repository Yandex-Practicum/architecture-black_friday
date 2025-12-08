import json
import logging
import os
import time
from typing import List, Optional, Callable, Any

from pymongo import AsyncMongoClient
from fastapi import Body, FastAPI, HTTPException, status, Request
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache
from logmiddleware import RouterLoggingMiddleware, logging_config
from pydantic import BaseModel, Field
from pydantic.functional_validators import BeforeValidator
from pymongo import errors
from redis import asyncio as aioredis
from typing_extensions import Annotated


fmt = logging_config["formatters"]["json"]["format"]
if "%(message)s" not in fmt:
    logging_config["formatters"]["json"]["format"] = f"{fmt} %(message)s"
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


def collection_ns_key_builder(
    func: Callable[..., Any],
    namespace: str | None,
    request: Request,
    response: Any,
    args: tuple[Any, ...],
    kwargs: dict[str, Any],
) -> str:
    prefix = FastAPICache.get_prefix()
    collection = request.path_params.get("collection_name", "default")
    # формируем хвост: путь без первого сегмента + query
    segments = [s for s in request.url.path.split("/") if s]
    tail = "/".join(segments[1:]) if len(segments) > 1 else ""
    items = sorted(request.query_params.multi_items())
    if items:
        qs = "&".join(f"{k}={v}" for k, v in items)
        tail = f"{tail}?{qs}" if tail else f"?{qs}"
    return f"{prefix}:{collection}:{tail}"

client = AsyncMongoClient(DATABASE_URL)
db = client[DATABASE_NAME]

# Represents an ObjectId field in the database.
# It will be represented as a `str` on the model so that it can be serialized to JSON.
PyObjectId = Annotated[str, BeforeValidator(str)]


@app.on_event("startup")
async def startup():
    if REDIS_URL:
        redis = aioredis.from_url(REDIS_URL, encoding="utf8", decode_responses=True)
        FastAPICache.init(RedisBackend(redis), prefix="api:cache", key_builder=collection_ns_key_builder)


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
    try:
        replica_status = await client.admin.command("replSetGetStatus")
        replica_status = json.dumps(replica_status, indent=2, default=str)
    except errors.OperationFailure:
        replica_status = "No Replicas"

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

    collection_names = await db.list_collection_names()
    collections = {}
    shard_distribution_for_collections = await get_shard_distribution_info() if topology_type == "Sharded" else {}
    for collection_name in collection_names:
        collection = db.get_collection(collection_name)
        collection_info = {
            "documents_count": await collection.count_documents({}),
            "shard_distribution": shard_distribution_for_collections.get(f"{DATABASE_NAME}.{collection_name}", [])
        }

        collections[collection_name] = collection_info

    cache_enabled = False
    if REDIS_URL:
        cache_enabled = FastAPICache.get_enable()

    return {
        "mongo_topology_type": topology_type,
        "mongo_replicaset_name": replicaset_name,
        "mongo_db": DATABASE_NAME,
        "read_preference": str(read_preference),
        "mongo_nodes": list(client.nodes),
        "mongo_primary_host": await client.primary,
        "mongo_secondary_hosts": await client.secondaries,
        "mongo_is_primary": await client.is_primary,
        "mongo_is_mongos": await client.is_mongos,
        "collections": collections,
        "shards": shards,
        "cache_enabled": cache_enabled,
        "status": "OK",
    }

async def get_shard_distribution_info() -> dict[str, list]:
    pipeline = [{"$shardedDataDistribution":{}}]
    cursor = await client["admin"].aggregate(pipeline)
    return {ns['ns']: ns['shards'] async for ns in cursor}


@app.get("/{collection_name}/count")
@cache(expire=60 * 1)
async def collection_count(collection_name: str):
    collection = db.get_collection(collection_name)
    items_count = await collection.count_documents({})
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
    await FastAPICache.clear(namespace=collection_name)
    created_user = await collection.find_one({"_id": new_user.inserted_id})
    return created_user