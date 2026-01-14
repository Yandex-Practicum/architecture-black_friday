import json
import logging
import os
import time
from typing import List, Optional

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
import asyncio
from fastapi.encoders import jsonable_encoder
from fastapi import Request
import functools
import inspect
from fastapi.responses import JSONResponse

def redis_cache(ttl: int = 60, prefix: str = "rc"):
    """
    Простой кеш через Redis:
    - key = {prefix}:{METHOD}:{PATH}?{QUERY}
    - value = JSON
    Требования: глобальная переменная `redis` должна быть инициализирована в startup().
    """
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            # 1) Достаём Request (FastAPI передаст его, если он есть в параметрах эндпоинта)
            request: Request | None = kwargs.get("request")
            if request is None:
                for a in args:
                    if isinstance(a, Request):
                        request = a
                        break

            if request is None:
                # без request не сможем построить стабильный ключ
                logger.warning("redis_cache: no Request in endpoint args -> bypass cache")
                return await func(*args, **kwargs)

            # 2) Если redis не поднят — тоже просто bypass
            r = globals().get("redis")
            if r is None:
                logger.warning("redis_cache: redis is None -> bypass cache")
                return await func(*args, **kwargs)

            key = f"{prefix}:{request.method}:{request.url.path}?{request.url.query}"

            # 3) TRY GET
            t0 = time.perf_counter()
            cached = await r.get(key)
            t1 = time.perf_counter()

            if cached is not None:
                logger.info("REDIS CACHE HIT key=%s get_ms=%.2f", key, (t1 - t0) * 1000)
                # cached — строка JSON
                return JSONResponse(content=json.loads(cached))

            logger.info("REDIS CACHE MISS key=%s get_ms=%.2f", key, (t1 - t0) * 1000)

            # 4) Выполняем реальную функцию
            result = await func(*args, **kwargs)

            # 5) Сериализуем в JSON-safe и SETEX
            payload = jsonable_encoder(result)

            t2 = time.perf_counter()
            await r.setex(key, ttl, json.dumps(payload))
            t3 = time.perf_counter()
            logger.info("REDIS CACHE SET key=%s set_ms=%.2f ttl=%s", key, (t3 - t2) * 1000, ttl)

            return result

        return wrapper
    return decorator

# Configure JSON logging
logging.config.dictConfig({
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {"format": "%(asctime)s %(levelname)s %(name)s: %(message)s"}
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "default",
            "stream": "ext://sys.stdout",
        }
    },
    "root": {"level": "INFO", "handlers": ["console"]},
})
logger = logging.getLogger(__name__)

app = FastAPI()
app.add_middleware(
    RouterLoggingMiddleware,
    logger=logger,
)

DATABASE_URL = os.environ["MONGODB_URL"]
DATABASE_NAME = os.environ["MONGODB_DATABASE_NAME"]
REDIS_URL = os.getenv("REDIS_URL", None)
redis = None


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

# Represents an ObjectId field in the database.
# It will be represented as a `str` on the model so that it can be serialized to JSON.
PyObjectId = Annotated[str, BeforeValidator(str)]


@app.on_event("startup")
async def startup():
    global redis
    print("### STARTUP FIRED ###", flush=True)

    if REDIS_URL:
        try:
            redis = aioredis.from_url(REDIS_URL, encoding="utf8", decode_responses=True)
            await redis.ping()
            logger.info("Redis ENABLED, redis=%s", REDIS_URL)
        except Exception:
            redis = None
            logger.exception("Redis FAILED to init")
    else:
        logger.warning("Redis DISABLED: REDIS_URL not set")




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
    collection_names = await db.list_collection_names()
    collections = {}
    for collection_name in collection_names:
        collection = db.get_collection(collection_name)
        collections[collection_name] = {
            "documents_count": await collection.count_documents({})
        }
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

    cache_enabled = False
    if REDIS_URL:
        cache_enabled = FastAPICache.get_enable()

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
@redis_cache(ttl=60, prefix="users")
async def list_users(collection_name: str, request: Request):
    logger.info(
        "ENTER list_users | path=%s | query=%s | headers.host=%s",
        request.url.path,
        request.url.query,
        request.headers.get("host"),
    )

    logger.info("SLEEP START")
    await asyncio.sleep(1)
    logger.info("SLEEP END")

    collection = db.get_collection(collection_name)
    users = await collection.find().to_list(1000)

    logger.info("RETURN %d users", len(users))
    return UserCollection(users=users)



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
