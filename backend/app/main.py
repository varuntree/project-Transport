from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.utils.logging import configure_logging, get_logger
from app.db.supabase_client import test_supabase_connection
from app.db.redis_client import test_redis_connection
from app.api.v1 import stops, routes, gtfs, trips, internal

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

# Register API routers
app.include_router(stops.router, prefix="/api/v1", tags=["stops"])
app.include_router(routes.router, prefix="/api/v1", tags=["routes"])
app.include_router(gtfs.router, prefix="/api/v1/gtfs", tags=["gtfs"])
app.include_router(trips.router, prefix="/api/v1", tags=["trips"])
app.include_router(internal.router, prefix="/api/v1", tags=["internal"])

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
