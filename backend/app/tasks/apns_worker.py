"""APNs worker task: batch push notification fan-out (Phase 6).

PHASE 2 STUB: Registered to satisfy task_routes, no-op until Phase 6 implementation.
"""

from app.tasks.celery_app import app
from app.utils.logging import get_logger

logger = get_logger(__name__)


@app.task(
    name="app.tasks.apns_worker.send_push_notifications",
    queue="normal",
    bind=True,
    max_retries=3,
    time_limit=120,
    soft_time_limit=90,
)
def send_push_notifications(self, notification_batch=None):
    """Send push notifications via APNs (Apple Push Notification Service).

    PHASE 2: Stub task to prevent Celery unregistered task errors.
    PHASE 6: Implement PyAPNs2 batch fan-out with 3-layer dedup.

    Args:
        notification_batch: List of dicts with {user_id, device_token, payload}

    Returns:
        None (stateless task, no result backend)
    """
    logger.info(
        "apns_worker_invoked",
        task_id=self.request.id,
        status="stub_noop",
        phase="2",
        batch_size=len(notification_batch) if notification_batch else 0,
        message="APNs worker not yet implemented (Phase 6 feature)",
    )
    # Phase 6 will:
    # 1. Validate device tokens (check registration, dedup)
    # 2. Build APNs payloads with quiet hours logic
    # 3. Fan-out via PyAPNs2 with error handling
    # 4. Update Supabase notification_history table
    return None
