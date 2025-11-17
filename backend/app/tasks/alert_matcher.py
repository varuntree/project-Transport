"""Alert matcher task: matches delays/disruptions to user favorites (Phase 5/6).

PHASE 2 STUB: Registered to satisfy beat schedule, no-op until Phase 5 implementation.
"""

from app.tasks.celery_app import app
from app.utils.logging import get_logger

logger = get_logger(__name__)


@app.task(
    name="app.tasks.alert_matcher.match_delays_to_favorites",
    queue="normal",
    bind=True,
    max_retries=3,
    time_limit=120,
    soft_time_limit=90,
)
def match_delays_to_favorites(self):
    """Match GTFS-RT delays/service alerts to user favorites.

    PHASE 2: Stub task to prevent Celery unregistered task errors.
    PHASE 5: Implement SQL alert matching logic (see DATA_ARCHITECTURE.md).

    Returns:
        None (stateless task, no result backend)
    """
    logger.info(
        "alert_matcher_invoked",
        task_id=self.request.id,
        status="stub_noop",
        phase="2",
        message="Alert matcher not yet implemented (Phase 5 feature)",
    )
    # Phase 5 will:
    # 1. Query Supabase for active user favorites
    # 2. Fetch latest GTFS-RT delays from Redis
    # 3. Match delays to favorites via SQL/Redis index
    # 4. Enqueue APNs tasks for matched users
    return None
