"""NSW API GTFS downloader service.

Downloads GTFS ZIP files from NSW Transport API for 6 modes:
- Sydney Trains (v2 realtime-aligned)
- Metro
- Buses
- Sydney Ferries
- Manly Fast Ferry (MFF)
- Light Rail

Handles rate limiting (5 req/s limit), ZIP validation, and structured logging.
"""

import os
import time
import zipfile
from pathlib import Path
from typing import Dict, List
import requests

from app.config import settings
from app.utils.logging import get_logger

logger = get_logger(__name__)

# NSW API base URL and endpoints (validated 2025-11-13)
# Note: sydneytrains uses v1 (v2 returns 404), metro uses v2
NSW_API_BASE = "https://api.transport.nsw.gov.au"
GTFS_ENDPOINTS = {
    "sydneytrains": "/v1/gtfs/schedule/sydneytrains",
    "metro": "/v2/gtfs/schedule/metro",
    "buses": "/v1/gtfs/schedule/buses",
    "sydneyferries": "/v1/gtfs/schedule/ferries/sydneyferries",
    "mff": "/v1/gtfs/schedule/ferries/MFF",
    "lightrail": "/v1/gtfs/schedule/lightrail",
}

# Rate limiting: NSW API limit is 5 req/s, use 250ms delay = 4 req/s (safe margin)
DELAY_BETWEEN_REQUESTS = 0.25

# HTTP timeout for downloads (60 seconds per file)
DOWNLOAD_TIMEOUT = 60


def download_gtfs_feeds(output_dir: str = "temp/gtfs-downloads") -> Dict[str, str]:
    """Download all GTFS feeds from NSW API.

    Downloads 6 mode-specific GTFS ZIPs sequentially with rate limiting.
    Creates temp directory structure: {output_dir}/{mode}/gtfs.zip
    Unzips each file to {output_dir}/{mode}/*.txt

    Args:
        output_dir: Base directory for downloads (default: temp/gtfs-downloads)

    Returns:
        Dict mapping mode names to their output directories

    Raises:
        ValueError: If NSW_API_KEY is missing or invalid
        requests.HTTPError: If download fails
        zipfile.BadZipFile: If downloaded file is corrupted
    """
    # Validate API key
    if not settings.NSW_API_KEY or len(settings.NSW_API_KEY) < 10:
        logger.error("gtfs_download_failed", error="Missing or invalid NSW_API_KEY")
        raise ValueError("NSW_API_KEY must be set in environment")

    # Create output directory
    base_path = Path(output_dir)
    base_path.mkdir(parents=True, exist_ok=True)

    logger.info("gtfs_download_start", total_modes=len(GTFS_ENDPOINTS), output_dir=output_dir)

    start_time = time.time()
    mode_dirs = {}
    total_size_bytes = 0

    for mode, endpoint in GTFS_ENDPOINTS.items():
        mode_start_time = time.time()

        # Download and unzip for this mode
        mode_dir = base_path / mode
        mode_dir.mkdir(exist_ok=True)

        zip_path = mode_dir / "gtfs.zip"

        try:
            # Download ZIP
            size_bytes = _download_file(mode, endpoint, zip_path)
            total_size_bytes += size_bytes

            # Validate and unzip
            _validate_and_unzip(mode, zip_path, mode_dir)

            mode_dirs[mode] = str(mode_dir)

            mode_duration_ms = int((time.time() - mode_start_time) * 1000)
            size_mb = size_bytes / (1024 * 1024)

            logger.info(
                "gtfs_download_complete",
                mode=mode,
                size_mb=round(size_mb, 2),
                duration_ms=mode_duration_ms
            )

            # Rate limiting: delay before next request (except after last one)
            if mode != list(GTFS_ENDPOINTS.keys())[-1]:
                time.sleep(DELAY_BETWEEN_REQUESTS)

        except Exception as e:
            logger.error(
                "gtfs_download_failed",
                mode=mode,
                error=str(e),
                error_type=type(e).__name__
            )
            raise

    total_duration_ms = int((time.time() - start_time) * 1000)
    total_size_mb = total_size_bytes / (1024 * 1024)

    logger.info(
        "gtfs_download_all_complete",
        total_modes=len(mode_dirs),
        total_size_mb=round(total_size_mb, 2),
        total_duration_ms=total_duration_ms
    )

    return mode_dirs


def _download_file(mode: str, endpoint: str, output_path: Path) -> int:
    """Download a single GTFS ZIP file from NSW API.

    Args:
        mode: Transport mode name (for logging)
        endpoint: API endpoint path
        output_path: Local file path to save ZIP

    Returns:
        Size of downloaded file in bytes

    Raises:
        requests.HTTPError: If download fails
    """
    url = f"{NSW_API_BASE}{endpoint}"

    headers = {
        "Authorization": f"apikey {settings.NSW_API_KEY}",
        "Accept": "application/zip"
    }

    logger.info("gtfs_download_start", mode=mode, url=url)

    try:
        response = requests.get(
            url,
            headers=headers,
            timeout=DOWNLOAD_TIMEOUT,
            stream=True
        )
        response.raise_for_status()

        # Write to file
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        size_bytes = output_path.stat().st_size
        return size_bytes

    except requests.Timeout as e:
        logger.error("gtfs_download_timeout", mode=mode, url=url, timeout_seconds=DOWNLOAD_TIMEOUT)
        raise
    except requests.HTTPError as e:
        logger.error(
            "gtfs_download_http_error",
            mode=mode,
            url=url,
            status_code=e.response.status_code,
            error=str(e)
        )
        raise
    except Exception as e:
        logger.error(
            "gtfs_download_error",
            mode=mode,
            url=url,
            error=str(e),
            error_type=type(e).__name__
        )
        raise


def _validate_and_unzip(mode: str, zip_path: Path, output_dir: Path) -> None:
    """Validate ZIP integrity and extract contents.

    Args:
        mode: Transport mode name (for logging)
        zip_path: Path to ZIP file
        output_dir: Directory to extract files to

    Raises:
        zipfile.BadZipFile: If ZIP is corrupted
    """
    try:
        # Validate ZIP integrity by opening it
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            # Test ZIP integrity
            bad_file = zip_ref.testzip()
            if bad_file is not None:
                logger.error("gtfs_zip_corrupted", mode=mode, bad_file=bad_file)
                raise zipfile.BadZipFile(f"Corrupted file in ZIP: {bad_file}")

            # Extract all files
            zip_ref.extractall(output_dir)

            file_list = zip_ref.namelist()
            logger.info(
                "gtfs_unzip_complete",
                mode=mode,
                file_count=len(file_list),
                files=file_list[:10]  # Log first 10 files only
            )

    except zipfile.BadZipFile as e:
        logger.error("gtfs_zip_invalid", mode=mode, error=str(e))
        raise
    except Exception as e:
        logger.error(
            "gtfs_unzip_error",
            mode=mode,
            error=str(e),
            error_type=type(e).__name__
        )
        raise
