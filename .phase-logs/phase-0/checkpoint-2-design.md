# Checkpoint 2: Backend Configuration

## Goal
Environment variable loader using Pydantic Settings with validation, clear errors if vars missing.

## Approach

### Backend Implementation
Create `backend/app/config.py`:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import HttpUrl, Field

class Settings(BaseSettings):
    """Application configuration loaded from .env.local"""

    # Supabase
    SUPABASE_URL: HttpUrl = Field(..., description="Supabase project URL")
    SUPABASE_ANON_KEY: str = Field(..., min_length=1)
    SUPABASE_SERVICE_KEY: str = Field(..., min_length=1)

    # Redis
    REDIS_URL: str = Field(..., description="Redis connection URL (Railway public URL)")

    # NSW API
    NSW_API_KEY: str = Field(..., min_length=1)

    # Server
    SERVER_HOST: str = Field(default="0.0.0.0")
    SERVER_PORT: int = Field(default=8000)
    LOG_LEVEL: str = Field(default="INFO")

    model_config = SettingsConfigDict(
        env_file=".env.local",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

# Global singleton
settings = Settings()
```

**Key pattern:**
- Use `Field(..., description="...")` for required vars
- Pydantic will raise clear ValidationError if missing
- Use `HttpUrl` for URL validation
- `extra="ignore"` allows extra vars in .env.local without errors

### iOS Implementation
None

## Design Constraints
- Follow DEVELOPMENT_STANDARDS.md:L940-963 pattern
- All vars must have type hints
- Required vars use `Field(...)` (ellipsis)
- Error messages guide user to .env.example

## Risks
- User runs without .env.local → ValidationError
  - Mitigation: Error message says "Create .env.local from .env.example"
- REDIS_URL might have wrong format
  - Mitigation: No strict validation yet (test in checkpoint 3)

## Validation
```bash
cd backend
python -c 'from app.config import settings; print(settings.SUPABASE_URL)'
# Expected: Prints URL (not None), no import errors
```

## References for Subagent
- Pattern: DEVELOPMENT_STANDARDS.md:L940-963
- Pydantic Settings docs: https://docs.pydantic.dev/latest/concepts/pydantic_settings/

## Estimated Complexity
**simple** - Standard Pydantic Settings pattern
