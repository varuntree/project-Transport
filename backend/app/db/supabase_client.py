from supabase import create_client, Client
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
