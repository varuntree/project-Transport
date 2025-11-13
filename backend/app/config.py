"""Application configuration loaded from environment variables.

Uses Pydantic Settings for validation and type safety.
Required variables must be present in .env.local or environment.
"""

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
