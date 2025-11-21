import structlog
import logging
import sys
import os
from pathlib import Path
from logging.handlers import RotatingFileHandler

# Base directory for runtime artifacts; override with VAR_DIR env.
# Defaults to <repo>/var to keep generated files out of source tree.
VAR_DIR = Path(
    os.getenv(
        "VAR_DIR",
        Path(__file__).resolve().parent.parent.parent / "var"
    )
).resolve()

def configure_logging():
    """Configure structlog with JSON output for production"""

    # Create logs directory under var/
    log_dir = VAR_DIR / "log"
    log_dir.mkdir(parents=True, exist_ok=True)

    # Determine log file based on process type
    import sys
    if "celery" in sys.argv[0] or "celery" in " ".join(sys.argv):
        if "beat" in sys.argv:
            log_file = log_dir / "beat.log"
        elif "-Q critical" in " ".join(sys.argv):
            log_file = log_dir / "worker_critical.log"
        else:
            log_file = log_dir / "worker_service.log"
    else:
        log_file = log_dir / "fastapi.log"

    # Configure standard library logging with both stdout and file handlers
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.handlers = []  # Clear existing handlers

    # Stdout handler
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setFormatter(logging.Formatter("%(message)s"))
    root_logger.addHandler(stdout_handler)

    # File handler with rotation (10MB max, 7 backups)
    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=7
    )
    file_handler.setFormatter(logging.Formatter("%(message)s"))
    root_logger.addHandler(file_handler)

    # Configure structlog
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """Get a structured logger instance"""
    return structlog.get_logger(name)
