# Checkpoint 1: NSW API GTFS Downloader

## Goal
Backend downloads GTFS ZIPs from NSW API programmatically, unzips to temp dir. Must fetch 6 mode-specific endpoints, handle rate limits (5 req/s), validate ZIP integrity.

## Approach

### Backend Implementation
- Create `app/services/nsw_gtfs_downloader.py`
- Use `requests` library for HTTP downloads with NSW API authentication
- Files to create:
  - `app/services/nsw_gtfs_downloader.py` - Main downloader service with `download_gtfs_feeds()` function
- Files to modify: None (new service)
- Critical pattern: Structured logging (JSON events), no PII

### Implementation Details

**Endpoints to download (sequential):**
1. `/v2/gtfs/schedule/sydneytrains` - Realtime-aligned train data
2. `/v2/gtfs/schedule/metro` - Metro data
3. `/v1/gtfs/schedule/buses` - Bus data
4. `/v1/gtfs/schedule/ferries/sydneyferries` - Sydney Ferries
5. `/v1/gtfs/schedule/ferries/MFF` - Manly Fast Ferry
6. `/v1/gtfs/schedule/lightrail` - Light rail data

**Authentication:**
- Header: `Authorization: apikey {settings.NSW_API_KEY}`
- Header: `Accept: application/zip`

**Rate Limiting:**
- NSW API limit: 5 req/s
- Strategy: Sequential downloads with 250ms delay between requests
- Use `time.sleep(0.25)` after each download

**Download Process:**
1. Create temp directory: `temp/gtfs-downloads/`
2. For each mode endpoint:
   - Download ZIP to `temp/gtfs-downloads/{mode}/gtfs.zip`
   - Verify ZIP integrity (check magic bytes, try opening)
   - Unzip to `temp/gtfs-downloads/{mode}/`
   - Log: `logger.info("gtfs_download_complete", mode=mode, size_mb=size, duration_ms=duration)`
3. Validate all 6 modes downloaded successfully

**Error Handling:**
- HTTP errors: Log and raise exception (don't continue with partial data)
- ZIP corruption: Log and raise exception
- Network timeouts: 60s timeout per download
- Missing API key: Fail fast with clear error message

## Design Constraints
- Use NSW API token from `settings.NSW_API_KEY` (already in config.py)
- Base URL: `https://api.transport.nsw.gov.au`
- Reference NSW_API_REFERENCE.md:L94-106 for exact endpoint paths
- Sequential downloads only (avoid parallel to respect rate limit)
- Log structured events using existing `logger` from utils/logging.py
- Total download size: ~100-150MB (log individual file sizes)

## Risks
- **Rate limit exceeded:** Sequential with 250ms delay = 4 req/s (safe margin)
- **ZIP corruption during download:** Validate ZIP before unzipping
- **Disk space:** ~150MB temp storage (acceptable for modern systems)
- **Network failures:** Use requests timeout=60, catch exceptions, fail fast

## Validation
```bash
python -c "from app.services.nsw_gtfs_downloader import download_gtfs_feeds; download_gtfs_feeds()"
# Expected output (structured logs):
# gtfs_download_start: mode=sydneytrains
# gtfs_download_complete: mode=sydneytrains, size_mb=45.2, duration_ms=8500
# ... (repeat for 6 modes)
# gtfs_download_all_complete: total_modes=6, total_size_mb=127.3, total_duration_ms=52000

ls -lh temp/gtfs-downloads/*/
# Expected: 6 directories, each containing unzipped GTFS CSV files
# Files per mode: agency.txt, stops.txt, routes.txt, trips.txt, stop_times.txt, calendar.txt, etc.
```

## References for Subagent
- Exploration report: `critical_patterns` → "Structured logging (JSON events, no PII)"
- Standards: DEVELOPMENT_STANDARDS.md:Section 4.1 (logging patterns)
- Architecture: NSW_API_REFERENCE.md:L90-113 (GTFS download endpoints)
- Config: backend/app/config.py:L23 (NSW_API_KEY already defined)
- Logging: backend/app/utils/logging.py (existing logger)

## Estimated Complexity
**moderate** - HTTP downloads straightforward, but must handle rate limiting, ZIP validation, multiple endpoints, error cases properly
