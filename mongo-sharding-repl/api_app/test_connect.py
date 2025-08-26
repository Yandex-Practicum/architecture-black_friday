# test_connect.py
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

client = AsyncIOMotorClient('mongodb://mongos:27017', serverSelectionTimeoutMS=5000)

async def test():
    try:
        await client.admin.command('ping')
        print('✅ Подключение к mongos успешно')
    except Exception as e:
        print(f'❌ Ошибка: {e}')

asyncio.run(test())