# Checkpoint 4: Structured Logging

## Goal
JSON structured logging with structlog, no PII, event-driven pattern.

## Approach

### Backend Implementation

Create `backend/app/utils/logging.py`:

```python
import structlog
import logging
import sys

def configure_logging():
    """Configure structlog with JSON output for production"""

    # Configure standard library logging first
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.INFO,
    )

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

# Usage example (not in file):
# logger = get_logger(__name__)
# logger.info("server_started", port=8000)
# Output: {"event": "server_started", "port": 8000, "timestamp": "2025-11-13T10:30:45.123Z", "level": "info"}
```

**Critical pattern:**
- Event-driven logging: `logger.info("event_name", key=value)`
- NEVER log PII: email, name, tokens, full request bodies
- Always include context: stop_id, user_id, duration_ms

### iOS Implementation
None

## Design Constraints
- Follow DEVELOPMENT_STANDARDS.md:L556-596 pattern exactly
- Use JSONRenderer() for production logs
- TimeStamper must use ISO format
- NEVER log PII (email, name, tokens)

## Risks
- Logs too verbose → Hard to parse
  - Mitigation: Use LOG_LEVEL from config, default INFO
- Accidentally log secrets
  - Mitigation: Never log full request bodies, only IDs

## Validation
```bash
cd backend
python -c "
from app.utils.logging import configure_logging, get_logger
configure_logging()
logger = get_logger('test')
logger.info('test_event', port=8000)
"
# Expected: {"event": "test_event", "port": 8000, "timestamp": "...", "level": "info", "logger": "test"}
```

## References for Subagent
- Pattern: DEVELOPMENT_STANDARDS.md:L556-596
- structlog docs: https://www.structlog.org/en/stable/

## Estimated Complexity
**simple** - Standard structlog configuration
