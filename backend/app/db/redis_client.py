import redis.asyncio as redis
from app.config import settings

# Global singleton
_redis_client: redis.Redis | None = None

def get_redis() -> redis.Redis:
    """Get async Redis client singleton (for FastAPI Depends())"""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=10
        )
    return _redis_client

async def test_redis_connection() -> bool:
    """Test Redis connection with PING command"""
    try:
        client = get_redis()
        result = await client.ping()
        return result is True
    except Exception as e:
        return False
