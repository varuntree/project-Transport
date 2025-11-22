"""Service Alerts Service - Checkpoint 2.

Filters active ServiceAlerts by stop_id.

Architecture:
- Fetch sa:{mode}:v1 Redis blobs (gzipped JSON) for all modes
- Filter by informed_entity.stop_id
- Filter by active_period (current time within range)
- Return list of matching alerts

Graceful degradation:
- Redis miss → return empty array (not 500 error)
- Gzip/JSON error → log warning, continue with other modes
"""

import gzip
import json
import time
from typing import List
from app.utils.logging import get_logger

logger = get_logger(__name__)


class AlertService:
    """Service for fetching and filtering GTFS-RT ServiceAlerts."""

    def __init__(self, redis_binary):
        """Initialize AlertService with Redis binary client.

        Args:
            redis_binary: Redis client with decode_responses=False for binary blobs
        """
        self.redis_binary = redis_binary

    def get_alerts_for_stop(self, stop_id: str) -> List[dict]:
        """Fetch active ServiceAlerts affecting this stop.

        Logic:
        1. Check ALL modes (stop can serve multiple modes, e.g., Central Station)
        2. Fetch sa:{mode}:v1 blobs from Redis for all modes
        3. Filter alerts by informed_entity.stop_id == stop_id
        4. Filter by active_period (current time within range)
        5. Return list of matching alerts

        Args:
            stop_id: GTFS stop_id

        Returns:
            List of ServiceAlert dicts matching this stop
        """
        # Check all modes (stops can serve multiple modes)
        # Example: Central Station serves trains, buses, lightrail
        modes_to_check = ['sydneytrains', 'metro', 'buses', 'ferries', 'lightrail']

        all_alerts = []
        current_timestamp = int(time.time())

        for mode in modes_to_check:
            try:
                # Fetch Redis blob
                redis_key = f"sa:{mode}:v1"
                compressed_data = self.redis_binary.get(redis_key)

                if not compressed_data:
                    logger.debug("alert_blob_miss", mode=mode, stop_id=stop_id)
                    continue

                # Decompress + parse
                decompressed = gzip.decompress(compressed_data)
                mode_alerts = json.loads(decompressed.decode('utf-8'))

                # Filter by stop_id in informed_entity
                for alert in mode_alerts:
                    # Check if alert affects this stop
                    affects_stop = any(
                        entity.get('stop_id') == stop_id
                        for entity in alert.get('informed_entity', [])
                    )

                    if not affects_stop:
                        continue

                    # Check active period
                    active_periods = alert.get('active_period', [])
                    is_active = self._is_alert_active(active_periods, current_timestamp)

                    if is_active:
                        all_alerts.append(alert)

            except gzip.BadGzipFile:
                logger.warning("alert_gzip_error", mode=mode, stop_id=stop_id)
                continue
            except json.JSONDecodeError as exc:
                logger.warning("alert_json_error", mode=mode, stop_id=stop_id, error=str(exc))
                continue
            except Exception as exc:
                logger.error("alert_fetch_failed", mode=mode, stop_id=stop_id, error=str(exc))
                continue

        logger.info("alerts_fetched", stop_id=stop_id, count=len(all_alerts))
        return all_alerts

    def _is_alert_active(self, active_periods: List[dict], current_timestamp: int) -> bool:
        """Check if alert is currently active based on active_period.

        Args:
            active_periods: List of {start: int, end: int} time ranges (Unix timestamps)
            current_timestamp: Current Unix timestamp

        Returns:
            True if alert is active (within at least one active period)
        """
        # If no active periods, assume always active
        if not active_periods:
            return True

        # Check if current time is within any active period
        for period in active_periods:
            start = period.get('start')
            end = period.get('end')

            after_start = start is None or current_timestamp >= start
            before_end = end is None or current_timestamp <= end

            if after_start and before_end:
                return True

        return False


# Singleton instance factory (imported by endpoints)
_alert_service = None


def get_alert_service():
    """Get AlertService singleton instance.

    Lazy initialization to ensure Redis client is available.
    Uses get_redis_binary() from realtime_service for binary blob access.
    """
    global _alert_service
    if _alert_service is None:
        from app.services.realtime_service import get_redis_binary
        redis_binary = get_redis_binary()
        _alert_service = AlertService(redis_binary)
    return _alert_service
