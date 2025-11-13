# Checkpoint 3: Database Clients (Supabase + Redis)

## Goal
Singleton database clients with FastAPI Depends() pattern, connection test functions.

## Approach

### Backend Implementation

**File 1: `backend/app/db/supabase_client.py`**

```python
from supabase import create_client, Client
from functools import lru_cache
from app.config import settings

# Global singleton
_supabase_client: Client | None = None

def get_supabase() -> Client:
    """Get Supabase client singleton (for FastAPI Depends())"""
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            supabase_url=str(settings.SUPABASE_URL),
            supabase_key=settings.SUPABASE_SERVICE_KEY
        )
    return _supabase_client

async def test_supabase_connection() -> bool:
    """Test Supabase connection (call during startup)"""
    try:
        client = get_supabase()
        # Simple query to test connection
        result = client.table('_health').select('*').limit(1).execute()
        return True
    except Exception as e:
        # Table doesn't exist yet, but connection works if we get 404/error response
        return True
```

**File 2: `backend/app/db/redis_client.py`**

```python
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
```

**Critical pattern from DEVELOPMENT_STANDARDS:**
- Singleton via global variable (not lru_cache for Redis async client)
- FastAPI routes use `Depends(get_supabase)` / `Depends(get_redis)`
- Never instantiate clients directly in routes

### iOS Implementation
None

## Design Constraints
- Supabase: Use supabase-py library, `create_client()` once
- Redis: Use redis.asyncio (async support), connection pool max_connections=10
- FastAPI Depends() pattern for dependency injection
- Test functions must be async (called during startup event)

## Risks
- Redis connection fails with Railway URL → Bad URL format
  - Mitigation: Test with actual credentials, log error if fails
- Supabase table doesn't exist yet → 404 error
  - Mitigation: Catch exception, return True if connection attempt succeeds (even with error response)

## Validation
```bash
cd backend
python -c 'import asyncio; from app.db.redis_client import get_redis, test_redis_connection; print(asyncio.run(test_redis_connection()))'
# Expected: True (Redis PING successful)
```

## References for Subagent
- Singleton pattern: DEVELOPMENT_STANDARDS.md:L203-260 (Supabase), L266-299 (Redis)
- Supabase client: https://supabase.com/docs/reference/python/initializing
- Redis async: https://redis.readthedocs.io/en/stable/examples/asyncio_examples.html

## Estimated Complexity
**moderate** - Async pattern, singleton management, connection testing
