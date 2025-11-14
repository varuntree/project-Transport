"""Celery application configuration with 3 queues and Beat scheduler.

Configured for:
- 3 queues: critical (RT poller), normal (alerts/APNs), batch (GTFS sync)
- DST-safe scheduling (Australia/Sydney timezone)
- Worker prefetch=1 for singleton pattern
- No result backend (stateless tasks)
"""

import os
from celery import Celery
from celery.schedules import crontab

from app.config import settings
from app.utils.logging import get_logger

logger = get_logger(__name__)

# Initialize Celery app
app = Celery("sydney_transit_backend")

# Celery configuration
app.conf.update(
    # Broker (Redis)
    broker_url=settings.REDIS_URL,

    # No result backend (stateless, ephemeral tasks)
    result_backend=None,

    # Task routing: 3 queues for isolation
    task_routes={
        "app.tasks.gtfs_rt_poller.poll_gtfs_rt": {"queue": "critical"},
        "app.tasks.alert_matcher.match_delays_to_favorites": {"queue": "normal"},
        "app.tasks.apns_worker.send_push_notifications": {"queue": "normal"},
        "app.tasks.gtfs_static_sync.sync_gtfs_static": {"queue": "batch"},
    },
    task_default_queue="normal",

    # Acks & redelivery (tasks must be idempotent)
    task_acks_late=True,
    task_reject_on_worker_lost=True,

    # Fairness: no hoarding (critical for singleton RT poller)
    worker_prefetch_multiplier=1,

    # Global defaults
    task_time_limit=300,  # 5 min hard
    task_soft_time_limit=240,  # 4 min soft

    # Worker recycling
    worker_max_tasks_per_child=100,
    worker_max_memory_per_child=200_000,  # ~200MB

    # Broker transport options (Redis)
    broker_transport_options={
        "visibility_timeout": 3700,  # > longest task (60m GTFS sync)
        "health_check_interval": 30,
    },

    # Publishing resilience
    task_publish_retry=True,
    broker_connection_retry_on_startup=True,

    # Serialization
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Timezone (DST-safe)
    timezone="Australia/Sydney",
    enable_utc=True,  # Celery handles TZ conversion

    # Beat scheduling
    beat_cron_starting_deadline=120,  # Don't catch up old slots after restart
    beat_max_loop_interval=30,  # Poll for sub-minute schedules

    # Task discovery
    include=["app.tasks.gtfs_rt_poller"],
)

# Beat schedule (DST-safe cron times)
app.conf.beat_schedule = {
    # GTFS-RT poller: every 30s
    "poll-gtfs-rt": {
        "task": "app.tasks.gtfs_rt_poller.poll_gtfs_rt",
        "schedule": 30.0,
        "options": {
            "queue": "critical",
            "expires": 25,  # Skip if delayed >25s
            "priority": 7,
        },
    },

    # GTFS static sync: daily at 03:10 Sydney (avoids DST hazard window)
    "sync-gtfs-static": {
        "task": "app.tasks.gtfs_static_sync.sync_gtfs_static",
        "schedule": crontab(hour=3, minute=10),
        "options": {
            "queue": "batch",
            "expires": 4 * 3600,  # 4 hours
            "time_limit": 5400,  # 90 min hard
            "soft_time_limit": 3600,  # 60 min soft
            "priority": 5,
        },
    },

    # Alert matcher: peak (every 2 min) + off-peak (every 5 min)
    "alert-matcher-peak": {
        "task": "app.tasks.alert_matcher.match_delays_to_favorites",
        "schedule": crontab(minute="*/2", hour="7-9,17-19"),
        "options": {
            "queue": "normal",
            "expires": 60,
            "priority": 6,
        },
    },
    "alert-matcher-offpeak": {
        "task": "app.tasks.alert_matcher.match_delays_to_favorites",
        "schedule": crontab(minute="*/5", hour="0-6,10-16,20-23"),
        "options": {
            "queue": "normal",
            "expires": 180,
            "priority": 6,
        },
    },
}

logger.info(
    "celery_configured",
    broker=settings.REDIS_URL.split("@")[-1] if "@" in settings.REDIS_URL else "localhost",
    queues=["critical", "normal", "batch"],
    timezone="Australia/Sydney",
)
