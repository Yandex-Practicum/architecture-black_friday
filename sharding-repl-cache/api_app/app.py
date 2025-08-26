import asyncio
import json
import os
import logging
from typing import List, Optional

# Настройка логгирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)
logger = logging.getLogger(__name__)

from fastapi import Body, FastAPI, HTTPException, status
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache

import motor.motor_asyncio
from bson import ObjectId
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from pydantic.functional_validators import BeforeValidator
from pymongo import errors
from redis import asyncio as aioredis
from typing_extensions import Annotated

app = FastAPI()

# === Переменные окружения ===
DATABASE_URL = os.environ["MONGODB_URL"]
DATABASE_NAME = os.environ["MONGODB_DATABASE_NAME"]
REDIS_URL = os.getenv("REDIS_URL", None)

# === Кеширование ===
def nocache(*args, **kwargs):
    def decorator(func):
        return func
    return decorator

# Используем отдельную переменную, чтобы избежать рекурсии
if REDIS_URL:
    use_cache = cache
else:
    use_cache = nocache

# === Глобальные переменные ===
client = None
db = None

# === Ожидание готовности MongoDB ===
async def wait_for_mongodb():
    """Ждём, пока mongos будет готов к подключениям"""
    temp_client = motor.motor_asyncio.AsyncIOMotorClient(
        DATABASE_URL,
        serverSelectionTimeoutMS=10000
    )
    for _ in range(60):  # 60 попыток × 2 сек = 2 минуты
        try:
            await temp_client.admin.command('ping')
            logger.info("✅ MongoDB (mongos) доступен")
            return temp_client
        except Exception as e:
            logger.warning(f"❌ Пока не могу подключиться: {e}")
            await asyncio.sleep(2)
    raise Exception("❌ Не удалось подключиться к MongoDB за 2 минуты")

# === Инициализация тестовых данных ===
async def initialize_test_data():
    collection = db["helloDoc"]
    count = await collection.count_documents({})
    if count < 1000:
        docs = []
        for i in range(count, 1000):
            docs.append({
                "name": f"test_user_{i}",
                "value": f"data_{i}",
                "age": i % 83 + 18
            })
        await collection.insert_many(docs)
        logger.info(f"✅ Добавлено {len(docs)} документов")
    else:
        # Добавить age, если его нет
        async for doc in collection.find({"age": {"$exists": False}}):
            await collection.update_one(
                {"_id": doc["_id"]},
                {"$set": {"age": 18}}  # значение по умолчанию
            )
        logger.info(f"ℹ️ helloDoc содержит {count} документов. Поля age обновлены.")

# === Модели Pydantic ===
PyObjectId = Annotated[str, BeforeValidator(str)]

class UserModel(BaseModel):
    model_config = ConfigDict(extra="allow")  # или extra="ignore"

    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    age: int = Field(...)
    name: str = Field(...)

class UserCollection(BaseModel):
    users: List[UserModel]

# === Startup ===
@app.on_event("startup")
async def startup():
    global client, db

    # Ждём готовности MongoDB
    client = await wait_for_mongodb()
    db = client[DATABASE_NAME]

    # Инициализация кеша
    if REDIS_URL:
        redis = aioredis.from_url(REDIS_URL, encoding="utf8", decode_responses=True)
        FastAPICache.init(RedisBackend(redis), prefix="api:cache")
        logger.info("✅ Кеширование с Redis включено")

    # Заполняем данные
    await initialize_test_data()

# === Эндпоинты ===
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
        for shard in shards_list.get("shards", []):
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
    return {"status": "OK", "mongo_db": DATABASE_NAME, "items_count": items_count}

@app.get(
    "/{collection_name}/users",
    response_description="List all users",
    response_model=UserCollection,
    response_model_by_alias=False,
)
@use_cache(expire=60 * 1)
async def list_users(collection_name: str):
    """
    List all of the user data in the database.
    The response is unpaginated and limited to 1000 results.
    """
    await asyncio.sleep(1)  # Имитация нагрузки — асинхронная задержка
    collection = db.get_collection(collection_name)
    return UserCollection(users=await collection.find().to_list(1000))

@app.get(
    "/{collection_name}/users/{name}",
    response_description="Get a single user",
    response_model=UserModel,
    response_model_by_alias=False,
)
async def show_user(collection_name: str, name: str):
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
    collection = db.get_collection(collection_name)
    new_user = await collection.insert_one(user.model_dump(by_alias=True, exclude=["id"]))
    created_user = await collection.find_one({"_id": new_user.inserted_id})
    return created_user