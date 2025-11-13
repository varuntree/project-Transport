# Checkpoint 5: FastAPI Hello World

## Goal
FastAPI server with /health and / endpoints, startup event tests DB/Redis connections, structured logs.

## Approach

### Backend Implementation

Create `backend/app/main.py`:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.utils.logging import configure_logging, get_logger
from app.db.supabase_client import test_supabase_connection
from app.db.redis_client import test_redis_connection

# Configure logging at module level
configure_logging()
logger = get_logger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("server_starting")

    # Test database connections
    db_ok = await test_supabase_connection()
    redis_ok = await test_redis_connection()

    if db_ok:
        logger.info("db_connected")
    else:
        logger.error("db_connection_failed")

    if redis_ok:
        logger.info("redis_connected")
    else:
        logger.error("redis_connection_failed")

    logger.info("server_started", port=8000)

    yield

    # Shutdown
    logger.info("server_stopping")

app = FastAPI(
    title="Sydney Transit API",
    version="0.1.0",
    lifespan=lifespan
)

# CORS middleware (allow localhost for iOS simulator)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:*", "http://127.0.0.1:*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "data": {
            "message": "Sydney Transit API",
            "version": "0.1.0"
        },
        "meta": {}
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    db_ok = await test_supabase_connection()
    redis_ok = await test_redis_connection()

    status = "healthy" if (db_ok and redis_ok) else "degraded"

    return {
        "data": {
            "status": status,
            "services": {
                "db": "connected" if db_ok else "disconnected",
                "cache": "connected" if redis_ok else "disconnected"
            }
        },
        "meta": {}
    }
```

**Critical patterns:**
- Use `lifespan` context manager (not deprecated @app.on_event)
- All responses use API envelope: `{"data": {...}, "meta": {}}`
- /health must test actual connections (not just return 200)

### iOS Implementation
None

## Design Constraints
- API envelope: DEVELOPMENT_STANDARDS.md:L360-411
- CORS must allow localhost (iOS simulator uses localhost:8000)
- Startup must test connections and log results
- Use async/await throughout

## Risks
- Supabase/Redis connection fails → Server still starts (degraded mode)
  - Mitigation: Log errors but don't crash server
- CORS blocks iOS requests → Wrong origin pattern
  - Mitigation: Allow http://localhost:* wildcard

## Validation
```bash
cd backend
uvicorn app.main:app --reload &
sleep 3
curl http://localhost:8000/health
# Expected: 200 {"data": {"status": "healthy", "services": {"db": "connected", "cache": "connected"}}, "meta": {}}

curl http://localhost:8000/
# Expected: 200 {"data": {"message": "Sydney Transit API", "version": "0.1.0"}, "meta": {}}

# Check logs are JSON
# Expected console output: {"event": "server_started", "port": 8000, "timestamp": "...", "level": "info"}
```

## References for Subagent
- API envelope: DEVELOPMENT_STANDARDS.md:L360-411
- Health check: BACKEND_SPECIFICATION.md:Section 2.1
- FastAPI lifespan: https://fastapi.tiangolo.com/advanced/events/

## Estimated Complexity
**moderate** - FastAPI setup, async startup, CORS, API envelope
