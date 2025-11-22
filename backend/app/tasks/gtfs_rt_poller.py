"""GTFS-RT Poller Task - Checkpoint 2 + Phase 2.2 ServiceAlerts.

Polls NSW Transport API every 30s for 5 modes × 3 feeds (VehiclePositions + TripUpdates + ServiceAlerts).
Caches gzipped JSON blobs in Redis with 75s/90s TTL.

Architecture:
- Redis SETNX lock for idempotency (prevents duplicate polls)
- Gzip compression (~70% blob size reduction)
- Sequential fetch with per-mode timeout handling
- Structured logging (no full protobuf dumps, counts only)

NSW API Endpoints (from NSW_API_REFERENCE.md):
- VehiclePositions: /v1/gtfs/vehiclepos/{mode} OR /v2/gtfs/vehiclepos/{mode}
- TripUpdates: /v1/gtfs/realtime/{mode} OR /v2/gtfs/realtime/{mode}
- ServiceAlerts: /v2/gtfs/alerts/{mode} (v1 deprecated June 2022)

Modes:
- buses: /v1/gtfs/vehiclepos/buses, /v1/gtfs/realtime/buses, /v2/gtfs/alerts/buses
- sydneytrains: /v2/gtfs/vehiclepos/sydneytrains, /v2/gtfs/realtime/sydneytrains, /v2/gtfs/alerts/sydneytrains
- metro: /v2/gtfs/vehiclepos/metro, /v2/gtfs/realtime/metro, /v2/gtfs/alerts/metro
- ferries: /v1/gtfs/vehiclepos/ferries/sydneyferries, /v1/gtfs/realtime/ferries/sydneyferries, /v2/gtfs/alerts/ferries
- lightrail: /v1/gtfs/vehiclepos/lightrail, /v1/gtfs/realtime/lightrail, /v2/gtfs/alerts/lightrail

Cache keys:
- vp:{mode}:v1 (TTL 75s) - Vehicle positions
- tu:{mode}:v1 (TTL 90s) - Trip updates
- sa:{mode}:v1 (TTL 90s) - Service alerts
"""

import os
import gzip
import json
import time
from typing import Optional

import redis
import requests
from google.transit import gtfs_realtime_pb2
from celery.exceptions import SoftTimeLimitExceeded

from app.tasks.celery_app import app as celery_app
from app.config import settings
from app.utils.logging import get_logger

logger = get_logger(__name__)

# NSW API configuration
NSW_BASE_URL = "https://api.transport.nsw.gov.au"
NSW_API_KEY = settings.NSW_API_KEY
REQUEST_TIMEOUT = 8  # seconds (NSW API SLA)

# Mode configurations (endpoint versions from NSW_API_REFERENCE.md)
MODES_CONFIG = {
    "buses": {
        "vehiclepos_path": "/v1/gtfs/vehiclepos/buses",
        "realtime_path": "/v1/gtfs/realtime/buses",
    },
    "sydneytrains": {
        "vehiclepos_path": "/v2/gtfs/vehiclepos/sydneytrains",
        "realtime_path": "/v2/gtfs/realtime/sydneytrains",
    },
    "metro": {
        "vehiclepos_path": "/v2/gtfs/vehiclepos/metro",
        "realtime_path": "/v2/gtfs/realtime/metro",
    },
    "ferries": {
        # Use per-operator endpoint (Sydney Ferries only for MVP)
        "vehiclepos_path": "/v1/gtfs/vehiclepos/ferries/sydneyferries",
        "realtime_path": "/v1/gtfs/realtime/ferries/sydneyferries",
    },
    "lightrail": {
        "vehiclepos_path": "/v1/gtfs/vehiclepos/lightrail",
        "realtime_path": "/v1/gtfs/realtime/lightrail",
    },
}

# Redis client setup
_redis_client: Optional[redis.Redis] = None


def get_redis_client() -> redis.Redis:
    """Get singleton Redis client."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(settings.REDIS_URL, decode_responses=False)
    return _redis_client


def fetch_gtfs_rt(mode: str, feed_type: str) -> Optional[bytes]:
    """Fetch GTFS-RT feed from NSW API.

    Args:
        mode: Transport mode (buses, sydneytrains, metro, ferries, lightrail)
        feed_type: Feed type (vehiclepos or realtime)

    Returns:
        Protobuf binary data or None on error
    """
    path_key = f"{feed_type}_path"
    if mode not in MODES_CONFIG or path_key not in MODES_CONFIG[mode]:
        logger.error("invalid_mode_or_feed", mode=mode, feed_type=feed_type)
        return None

    path = MODES_CONFIG[mode][path_key]
    url = f"{NSW_BASE_URL}{path}"
    headers = {
        "Authorization": f"apikey {NSW_API_KEY}",
        "Accept": "application/x-google-protobuf",
    }

    try:
        response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        return response.content
    except requests.Timeout:
        logger.warning("nsw_api_timeout", mode=mode, feed_type=feed_type, url=path)
        return None
    except requests.HTTPError as exc:
        status_code = exc.response.status_code if exc.response else 0
        if status_code == 429:
            logger.error("nsw_api_rate_limit", mode=mode, feed_type=feed_type, url=path)
        elif status_code == 503:
            logger.warning("nsw_api_unavailable", mode=mode, feed_type=feed_type, url=path)
        else:
            logger.error("nsw_api_http_error", mode=mode, feed_type=feed_type, status_code=status_code, url=path)
        return None
    except Exception as exc:
        logger.error("nsw_api_error", mode=mode, feed_type=feed_type, error=str(exc), url=path)
        return None


def parse_vehicle_positions(pb_data: bytes) -> list[dict]:
    """Parse VehiclePositions protobuf into JSON-serializable dicts.

    Args:
        pb_data: Protobuf binary data

    Returns:
        List of vehicle position dicts
    """
    try:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(pb_data)

        vehicles = []
        for entity in feed.entity:
            if not entity.HasField("vehicle"):
                continue

            vehicle = entity.vehicle

            # Extract occupancy_status (enum 0-8, default 0=EMPTY)
            occupancy_status = None
            if vehicle.HasField("occupancy_status"):
                occupancy_status = vehicle.occupancy_status

            vehicle_data = {
                "vehicle_id": vehicle.vehicle.id if vehicle.HasField("vehicle") else None,
                "trip_id": vehicle.trip.trip_id if vehicle.HasField("trip") else None,
                "route_id": vehicle.trip.route_id if vehicle.HasField("trip") else None,
                "lat": vehicle.position.latitude if vehicle.HasField("position") else None,
                "lon": vehicle.position.longitude if vehicle.HasField("position") else None,
                "bearing": vehicle.position.bearing if vehicle.HasField("position") and vehicle.position.HasField("bearing") else None,
                "speed": vehicle.position.speed if vehicle.HasField("position") and vehicle.position.HasField("speed") else None,
                "timestamp": vehicle.timestamp if vehicle.HasField("timestamp") else None,
                "occupancy_status": occupancy_status,
            }
            vehicles.append(vehicle_data)

        return vehicles
    except Exception as exc:
        logger.error("parse_vehicle_positions_error", error=str(exc))
        return []


def parse_trip_updates(pb_data: bytes) -> list[dict]:
    """Parse TripUpdates protobuf into JSON-serializable dicts.

    Args:
        pb_data: Protobuf binary data

    Returns:
        List of trip update dicts
    """
    try:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(pb_data)

        trip_updates = []
        for entity in feed.entity:
            if not entity.HasField("trip_update"):
                continue

            trip_update = entity.trip_update

            # Extract stop time updates
            stop_time_updates = []
            for stu in trip_update.stop_time_update:
                stop_update = {
                    "stop_id": stu.stop_id if stu.HasField("stop_id") else None,
                    "arrival_delay": stu.arrival.delay if stu.HasField("arrival") and stu.arrival.HasField("delay") else None,
                    "departure_delay": stu.departure.delay if stu.HasField("departure") and stu.departure.HasField("delay") else None,
                }
                # Platform code may be available in GTFS-RT extensions (NSW-specific)
                # Currently not parsed - fallback to static GTFS or display None
                stop_time_updates.append(stop_update)

            trip_data = {
                "trip_id": trip_update.trip.trip_id if trip_update.HasField("trip") else None,
                "route_id": trip_update.trip.route_id if trip_update.HasField("trip") else None,
                "delay_s": trip_update.delay if trip_update.HasField("delay") else 0,
                "stop_time_updates": stop_time_updates,
            }
            trip_updates.append(trip_data)

        return trip_updates
    except Exception as exc:
        logger.error("parse_trip_updates_error", error=str(exc))
        return []


def parse_service_alerts(pb_data: bytes) -> list[dict]:
    """Parse ServiceAlert protobuf into JSON-serializable dicts.

    Args:
        pb_data: Protobuf binary data

    Returns:
        List of service alert dicts
    """
    try:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(pb_data)

        alerts = []
        for entity in feed.entity:
            if not entity.HasField("alert"):
                continue

            alert = entity.alert

            # Extract header text (required field)
            header_text = ""
            if alert.header_text.translation:
                header_text = alert.header_text.translation[0].text

            # Extract description text (optional)
            description_text = None
            if alert.description_text.translation:
                description_text = alert.description_text.translation[0].text

            # Extract active periods
            active_period = []
            for period in alert.active_period:
                active_period.append({
                    "start": period.start if period.HasField("start") else None,
                    "end": period.end if period.HasField("end") else None,
                })

            # Extract informed entities
            informed_entity = []
            for ie in alert.informed_entity:
                entity_data = {
                    "agency_id": ie.agency_id if ie.HasField("agency_id") else None,
                    "route_id": ie.route_id if ie.HasField("route_id") else None,
                    "route_type": ie.route_type if ie.HasField("route_type") else None,
                    "stop_id": ie.stop_id if ie.HasField("stop_id") else None,
                }
                # Extract trip descriptor if present
                if ie.HasField("trip"):
                    entity_data["trip"] = {"trip_id": ie.trip.trip_id}
                else:
                    entity_data["trip"] = None

                informed_entity.append(entity_data)

            alert_data = {
                "id": entity.id,
                "header_text": header_text,
                "description_text": description_text,
                "effect": alert.Effect.Name(alert.effect) if alert.HasField("effect") else None,
                "cause": alert.Cause.Name(alert.cause) if alert.HasField("cause") else None,
                "active_period": active_period,
                "informed_entity": informed_entity,
                "severity_level": alert.SeverityLevel.Name(alert.severity_level) if alert.HasField("severity_level") else None,
            }
            alerts.append(alert_data)

        return alerts
    except Exception as exc:
        logger.error("parse_service_alerts_error", error=str(exc))
        return []


def cache_blob(redis_client: redis.Redis, key: str, data: list, ttl: int) -> bool:
    """Cache gzipped JSON blob in Redis.

    Args:
        redis_client: Redis client instance
        key: Redis key
        data: Data to cache (JSON-serializable)
        ttl: Time-to-live in seconds

    Returns:
        True if cached successfully, False otherwise
    """
    try:
        json_data = json.dumps(data).encode("utf-8")
        compressed = gzip.compress(json_data)
        redis_client.set(key, compressed, ex=ttl)
        return True
    except Exception as exc:
        logger.error("cache_blob_error", key=key, error=str(exc))
        return False


@celery_app.task(
    name="app.tasks.gtfs_rt_poller.poll_gtfs_rt",
    queue="critical",
    bind=True,
    max_retries=0,  # No retries - next schedule tick handles it
    time_limit=15,  # Hard timeout
    soft_time_limit=10,  # Soft timeout
)
def poll_gtfs_rt(self):
    """Poll NSW GTFS-RT feeds for all modes.

    Fetches VehiclePositions, TripUpdates, and ServiceAlerts for 5 modes (15 API calls total).
    Uses Redis SETNX lock for idempotency.

    Cache keys:
    - vp:{mode}:v1 (TTL 75s) - Vehicle positions
    - tu:{mode}:v1 (TTL 90s) - Trip updates
    - sa:{mode}:v1 (TTL 90s) - Service alerts
    """
    start_time = time.time()
    redis_client = get_redis_client()

    # Acquire singleton lock (30s TTL, auto-expires if worker crashes)
    lock_key = "lock:poll_gtfs_rt"
    lock_acquired = redis_client.set(lock_key, "1", nx=True, ex=30)

    if not lock_acquired:
        logger.info("poll_gtfs_rt_skipped", reason="already_running")
        return

    try:
        logger.info("poll_gtfs_rt_started", timestamp=int(start_time))

        vp_count = 0
        tu_count = 0
        modes = list(MODES_CONFIG.keys())

        for mode in modes:
            # Fetch VehiclePositions
            vp_data = fetch_gtfs_rt(mode, "vehiclepos")
            if vp_data:
                parsed_vp = parse_vehicle_positions(vp_data)
                if parsed_vp:
                    cache_key = f"vp:{mode}:v1"
                    if cache_blob(redis_client, cache_key, parsed_vp, ttl=75):
                        vp_count += len(parsed_vp)
                        logger.debug("vp_cached", mode=mode, count=len(parsed_vp), key=cache_key)

            # Fetch TripUpdates
            tu_data = fetch_gtfs_rt(mode, "realtime")
            if tu_data:
                parsed_tu = parse_trip_updates(tu_data)
                if parsed_tu:
                    cache_key = f"tu:{mode}:v1"
                    if cache_blob(redis_client, cache_key, parsed_tu, ttl=90):
                        tu_count += len(parsed_tu)
                        logger.debug("tu_cached", mode=mode, count=len(parsed_tu), key=cache_key)

        # Fetch ServiceAlerts (v2 API, per-mode endpoints)
        # Map mode names to NSW API alert endpoint format
        alert_mode_map = {
            "buses": "buses",
            "sydneytrains": "sydneytrains",
            "metro": "metro",
            "ferries": "ferries",  # Combined endpoint for all ferry operators
            "lightrail": "lightrail",
        }

        sa_count = 0
        for mode, alert_mode in alert_mode_map.items():
            try:
                # Fetch from NSW API v2 alerts endpoint
                url = f"{NSW_BASE_URL}/v2/gtfs/alerts/{alert_mode}"
                headers = {
                    "Authorization": f"apikey {NSW_API_KEY}",
                    "Accept": "application/x-google-protobuf",
                }

                response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
                response.raise_for_status()

                # Parse alerts
                parsed_alerts = parse_service_alerts(response.content)

                if parsed_alerts:
                    # Compress + cache in Redis with 90s TTL
                    cache_key = f"sa:{mode}:v1"
                    if cache_blob(redis_client, cache_key, parsed_alerts, ttl=90):
                        sa_count += len(parsed_alerts)
                        logger.debug("sa_cached", mode=mode, count=len(parsed_alerts), key=cache_key)

            except requests.Timeout:
                logger.warning("alert_fetch_timeout", mode=mode, url=f"/v2/gtfs/alerts/{alert_mode}")
            except requests.HTTPError as exc:
                status_code = exc.response.status_code if exc.response else 0
                logger.warning("alert_fetch_http_error", mode=mode, status_code=status_code)
            except Exception as exc:
                # Graceful degradation: log error but continue to next mode
                logger.warning("alert_fetch_failed", mode=mode, error=str(exc))

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info(
            "poll_gtfs_rt_complete",
            modes=modes,
            duration_ms=duration_ms,
            vp_count=vp_count,
            tu_count=tu_count,
            sa_count=sa_count,
        )

    except SoftTimeLimitExceeded:
        logger.warning("poll_gtfs_rt_soft_timeout", duration_ms=int((time.time() - start_time) * 1000))
    except Exception as exc:
        logger.error("poll_gtfs_rt_error", error=str(exc), duration_ms=int((time.time() - start_time) * 1000))
    finally:
        # Always release lock
        redis_client.delete(lock_key)
