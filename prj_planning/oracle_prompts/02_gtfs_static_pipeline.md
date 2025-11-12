# ORACLE PROMPT: GTFS Static Data Ingestion Pipeline

**Consultation ID:** 02_gtfs_static_pipeline
**Context Document:** Attach `SYSTEM_OVERVIEW.md` when submitting this prompt
**Priority:** CRITICAL - Directly impacts app size (competitive advantage)
**Expected Consultation Time:** 3-5 hours (with research + optimization analysis)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Critical Constraint:** iOS app must be <50MB initial download (vs competitors' 100-200MB)
**Challenge:** NSW GTFS static data is 227MB compressed, ~500MB+ uncompressed
**Users:** 0 initially → 1K (6 months) → 10K (12 months)
**Developer:** Solo, no team

---

## Fixed Tech Stack (DO NOT CHANGE)

- **Backend:** FastAPI (Python 3.11+) + Celery workers
- **Database:** Supabase (PostgreSQL + PostGIS, 500MB free tier)
- **iOS:** Swift/SwiftUI, local SQLite via GRDB
- **File Storage:** Supabase Storage (1GB free), CloudFlare CDN (unlimited bandwidth free)
- **Hosting:** Railway or Fly.io (with persistent volumes)

**NO new external services allowed.**

---

## Problem Statement

Design a complete GTFS static data ingestion pipeline that:

1. **Downloads 227MB daily NSW GTFS ZIP** - Efficiently, with validation
2. **Processes & loads to Supabase** - Stay under 500MB free tier database limit
3. **Generates optimized iOS SQLite** - Target <30MB, ideally <20MB
4. **Distributes to iOS app** - Minimize app bundle size (<50MB total app)
5. **Handles updates efficiently** - Daily incremental updates, not full reimport
6. **Costs <$5/month** - File storage, compute, bandwidth

---

## Data Source Specifications (NSW GTFS Static)

### What We're Dealing With

**NSW Transport GTFS Static Feed:**
- **Format:** ZIP file containing CSV text files (GTFS standard)
- **Size:** ~227 MB compressed, ~500-700 MB uncompressed (estimated)
- **Update Frequency:** Daily (usually updated nightly, 2-4 AM Sydney time)
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains` (and similar for other modes)
- **Coverage:** All of NSW (Sydney metro + regional trains + buses)

### GTFS Files Included (Standard Structure)

```
GTFS_ZIP/
├── agency.txt              (~5 KB)      # Transit operators
├── stops.txt               (~2 MB)      # ~10,000 stops (Sydney + regional NSW)
├── routes.txt              (~100 KB)    # ~500-1000 routes
├── trips.txt               (~20 MB)     # ~50,000-100,000 trip instances
├── stop_times.txt          (~400 MB)    # LARGEST FILE - millions of rows
├── calendar.txt            (~10 KB)     # Service patterns (weekday/weekend)
├── calendar_dates.txt      (~500 KB)    # Exceptions (holidays, etc.)
├── shapes.txt              (~50 MB)     # Route geographic paths (for maps)
└── (optional files)        (~5 MB)      # transfers, frequencies, etc.
```

**Key Observation:**
- **stop_times.txt** is 80%+ of uncompressed size (every trip × every stop × schedule)
- **shapes.txt** is ~10% of size (nice-to-have for map visualization)
- **stops.txt, routes.txt, trips.txt** are ~5-10% combined

### NSW-Specific GTFS Extensions

**Custom Fields (NSW adds to standard GTFS):**
- `stops.txt`: Custom wheelchair accessibility codes
- `trips.txt`: `trip_note` field (operational notes)
- `stop_times.txt`: `stop_note` field
- **notes.txt**: Custom NSW file for service irregularities

**GTFS Pathways Extension:**
- Released June 2023 for accessibility
- Adds files: `pathways.txt`, `levels.txt`
- Provides step-by-step station navigation
- Size: ~5-10 MB additional

---

## Constraints (CRITICAL - Must Respect)

### 1. App Size Constraint (<50MB Total)

**Breakdown:**
- iOS binary (compiled Swift code): ~15-20 MB
- Assets (icons, images): ~5 MB
- Dependencies (GRDB, Supabase SDK, etc.): ~5-10 MB
- **Available for GTFS data:** ~10-20 MB maximum

**Competitive Context:**
- TripView: 5.44 MB total app (stores EVERYTHING offline, but dated architecture)
- Transit: 196 MB total app (bloated, includes unnecessary data)
- NextThere: 119 MB total app
- **Our goal:** <50 MB total, ideally <30 MB (modern + lightweight)

### 2. Database Size Constraint (500MB Supabase Free Tier)

**Challenge:**
- Full NSW GTFS uncompressed: ~500-700 MB
- Supabase free tier: 500 MB limit
- **Must:** Optimize, exclude unnecessary data, or use clever schema

### 3. Sydney-Only Focus (Phase 1)

**Opportunity:**
- NSW GTFS includes regional areas (Wollongong, Newcastle, Blue Mountains, etc.)
- **Sydney metro users don't need regional data**
- Filtering Sydney-only could reduce data by 40-60%

**Sydney Definition (Oracle to decide):**
- Greater Sydney region (specific stops/routes)
- Exclude: Regional NSW trains, rural buses
- Include: All Sydney Trains, Metro, Buses, Ferries, Light Rail

### 4. Cost Constraint (<$5/month for GTFS pipeline)

**Storage:**
- Supabase Storage: 1 GB free (store raw GTFS ZIPs?)
- Railway/Fly.io volumes: ~$0.10/GB/month
- CloudFlare CDN: Free unlimited (serve iOS SQLite exports)

**Compute:**
- Celery daily task: ~30 min processing (estimate)
- Railway/Fly.io: Included in base plan ($5-20/month for whole backend)

### 5. Solo Developer Simplicity

- Automated pipeline (no manual intervention)
- Clear error handling (alerts if download/parsing fails)
- Idempotent (safe to re-run if crashes mid-process)
- Monitoring (know if data is stale)

---

## Questions for Oracle

### 1. Data Filtering & Optimization

**Question:** How to reduce 227 MB GTFS to <30 MB for iOS without losing critical functionality?

**Strategies to Evaluate:**

**A) Geographic Filtering (Sydney-Only)**
```sql
-- Which stops belong to "Sydney" vs "Regional NSW"?
-- Option 1: Bounding box (lat/lon)
-- Option 2: Agency ID (Sydney Trains vs NSW TrainLink)
-- Option 3: Stop name patterns ("Sydney" in name)
-- Oracle: Recommend best method + SQL query to filter
```

**B) Temporal Filtering (Next 7-14 Days Only)**
```
-- stop_times.txt has schedules for entire GTFS validity period (weeks/months)
-- Users only need next week's schedule
-- Oracle: How to filter stop_times by date range? Safe approach?
```

**C) Field Pruning (Remove Unnecessary Columns)**
```
-- Example: Do we need stop_desc (long descriptions)? Probably not.
-- Example: Do we need shape_dist_traveled? Maybe not if just showing routes.
-- Oracle: Which GTFS fields are safe to exclude?
```

**D) Shapes Optimization**
```
-- shapes.txt is ~50 MB (route paths for maps)
-- Options:
--   1) Exclude shapes entirely (use straight lines on map, ugly)
--   2) Simplify shapes (Douglas-Peucker algorithm, reduce point density)
--   3) Include only major routes (exclude bus shapes, keep train/metro)
-- Oracle: Recommend strategy (user experience vs file size trade-off)
```

**E) stop_times Compression**
```
-- stop_times.txt is 80% of data
-- Ideas:
--   1) Store only "pattern" trips (not every single trip instance)
--   2) Use delta encoding (store differences vs full times)
--   3) Compress with SQLite built-in compression (PRAGMA page_size, VACUUM)
-- Oracle: Recommend approach (research GTFS optimization techniques)
```

**Provide:**
- Estimated file size reduction for each strategy
- Recommended combination of strategies
- Trade-offs (what functionality is lost)

### 2. Pipeline Architecture & Flow

**Question:** Design end-to-end pipeline from NSW download to iOS delivery.

**Steps to Define:**

**Step 1: Download (Celery Task)**
```python
@app.task(name='gtfs_static_sync')
def sync_gtfs_static():
    """
    Runs daily at 3 AM Sydney time (Celery Beat schedule)
    """
    # 1. Download 227 MB ZIP from NSW API
    # Question: Where to store? (Supabase Storage, Railway volume, temp file?)
    # Question: How to validate? (checksum, file size, ZIP integrity?)

    # 2. Extract ZIP to temp directory
    # Question: Disk space needed? (500-700 MB uncompressed)

    # 3. Detect if data changed vs previous version
    # Question: Compare checksums? Timestamps? Version fields?
    # If no change, skip processing (save compute)
```

**Step 2: Parse & Transform**
```python
def parse_gtfs_csv(gtfs_dir):
    """
    Parse GTFS CSV files into Python data structures
    """
    # Oracle: Recommend Python library
    # Options: gtfs-kit, partridge, custom pandas parsing
    # Criteria: Memory efficient (500 MB data), fast, well-maintained

    # Filter data (Sydney-only, next 14 days, etc.)
    # Oracle: Provide filtering logic (pseudocode or SQL)
```

**Step 3: Load to Supabase**
```python
def load_to_supabase(parsed_data):
    """
    Bulk insert/upsert to PostgreSQL
    """
    # Oracle: Design efficient bulk load strategy
    # Options:
    #   A) Truncate tables + bulk insert (simpler, brief downtime)
    #   B) Upsert (slower, no downtime)
    #   C) Swap tables (blue-green deployment, complex)

    # Question: How to handle foreign keys during load?
    # Question: Index management (drop before load, rebuild after?)
```

**Step 4: Generate iOS SQLite**
```python
def generate_ios_sqlite():
    """
    Export filtered Supabase data to optimized SQLite file
    """
    # Oracle: Design SQLite schema (same as Supabase or optimized?)
    # Oracle: Compression techniques (PRAGMA settings)
    # Target: <20 MB final SQLite file

    # Upload to CloudFlare CDN (or Supabase Storage)
    # iOS app downloads on first launch or in background
```

**Provide:**
- Detailed flowchart (ASCII or description)
- Error handling at each step
- Rollback strategy if failure mid-pipeline
- Estimated runtime (target <30 min total)

### 3. Incremental Updates vs Full Import

**Question:** Should we do full import daily or incremental updates?

**Option A: Full Import (Simpler)**
```
Pros:
- Simple logic (just overwrite everything)
- No complex diff logic
- Guaranteed consistency

Cons:
- Longer processing time (~30 min daily)
- More database writes (wear on Supabase)
- Brief period of stale data during load

Pipeline:
Daily 3 AM:
1. Download GTFS ZIP
2. Truncate all GTFS tables
3. Bulk insert new data
4. Regenerate iOS SQLite
5. Upload to CDN
```

**Option B: Incremental Updates (Efficient)**
```
Pros:
- Faster updates (only changed data)
- Less database load
- Continuous availability (no truncate)

Cons:
- Complex diff logic (compare old vs new)
- Risk of data inconsistency (partial updates)
- Harder to debug

Pipeline:
Daily 3 AM:
1. Download GTFS ZIP
2. Compare with previous version (checksums per file)
3. For changed files:
   - Identify deltas (new, updated, deleted rows)
   - Upsert new/updated, delete removed
4. Regenerate iOS SQLite if changes
```

**Oracle Decides:**
- Which approach for MVP (0-1K users)?
- At what scale switch to incremental (if ever)?
- Recommend diff algorithm (if incremental chosen)

### 4. iOS SQLite Schema & Distribution

**Question:** How should iOS local SQLite be structured and delivered?

**Schema Design:**
```sql
-- Option A: Mirror Supabase schema exactly (simpler sync logic)
-- Option B: Denormalize for faster queries (larger file size)
-- Option C: Hybrid (normalize stops/routes, denormalize common queries)

-- Oracle: Recommend approach + provide SQLite CREATE TABLE statements
```

**SQLite Optimization:**
```sql
-- Techniques to apply:
PRAGMA page_size = 4096;  -- Or 8192? Oracle decides optimal
PRAGMA journal_mode = WAL;  -- Write-Ahead Logging
VACUUM;  -- Reclaim space

-- Indexes: Which indexes to create? (balance query speed vs file size)
CREATE INDEX idx_stops_name ON stops(stop_name);  -- Needed for search
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id, departure_time);  -- Needed for departures
-- Oracle: Define complete index strategy
```

**Distribution Strategy:**
```
Option A: Bundle in App (Increases app size to ~40-50 MB)
- Pros: Instant offline access, no download wait
- Cons: Violates <50 MB constraint if SQLite >10 MB

Option B: Download on First Launch (WiFi recommended)
- Pros: App stays <30 MB, user downloads ~20-30 MB data
- Cons: Requires internet on first use, 30-60 sec wait
- UI: "Downloading transit data... 15 MB / 20 MB"

Option C: Optional Offline Mode (P1 Feature)
- Pros: App <25 MB, advanced users opt-in to full data (~300 MB)
- Cons: Most users won't use offline mode
- Settings: "Enable Offline Mode" → downloads full GTFS

Oracle: Recommend strategy for Phase 1
```

**Background Download (If Option B/C):**
```swift
// iOS Background Assets framework (iOS 16+)
// Download large files in background, WiFi-only

import BackgroundAssets

func downloadGTFSData() {
    let request = BAURLDownloadRequest(
        identifier: "gtfs-sqlite-download",
        url: URL(string: "https://cdn.cloudflare.com/gtfs-sydney.sqlite")!,
        essential: true,
        fileSize: 25 * 1024 * 1024,  // 25 MB
        applicationGroupIdentifier: "group.com.transitapp"
    )

    // Oracle: Validate this approach, suggest improvements
}
```

### 5. Data Validation & Quality Checks

**Question:** How to ensure GTFS data quality after processing?

**Validation Checks:**
```python
def validate_gtfs_import():
    """
    Run after GTFS load to detect issues
    """
    checks = [
        # Row count checks (expect ~X rows for Sydney)
        ("stops_count", "SELECT COUNT(*) FROM stops", 1500, 3000),  # Expect ~2000 for Sydney
        ("routes_count", "SELECT COUNT(*) FROM routes", 300, 700),

        # Referential integrity (no orphaned records)
        ("orphan_trips", "SELECT COUNT(*) FROM trips t LEFT JOIN routes r ON t.route_id = r.route_id WHERE r.route_id IS NULL", 0, 0),
        ("orphan_stop_times", "SELECT COUNT(*) FROM stop_times st LEFT JOIN stops s ON st.stop_id = s.stop_id WHERE s.stop_id IS NULL", 0, 0),

        # Data quality (valid coordinates, etc.)
        ("invalid_coords", "SELECT COUNT(*) FROM stops WHERE stop_lat < -90 OR stop_lat > 90 OR stop_lon < -180 OR stop_lon > 180", 0, 0),
        ("missing_stop_names", "SELECT COUNT(*) FROM stops WHERE stop_name IS NULL OR stop_name = ''", 0, 0),

        # Oracle: What other validation checks are critical for GTFS data?
    ]

    # Run checks, alert if any fail
```

**Oracle Provide:**
- Complete validation checklist (10-15 checks)
- Expected value ranges for Sydney data
- Alerting strategy if validation fails

### 6. Cost & Performance Estimation

**Question:** Estimate costs and performance metrics.

**Cost Breakdown:**
```
File Storage:
- Supabase Storage (raw GTFS ZIPs): 227 MB × 7 days retention = 1.6 GB
  - Free tier: 1 GB → Exceeds free tier!
  - Solution: Keep only latest ZIP (227 MB), or upload to CloudFlare R2 (free)

- CloudFlare CDN (iOS SQLite): 20 MB file, 1K downloads/month
  - Free tier: Unlimited bandwidth ✅

Database Storage:
- Supabase PostgreSQL: Sydney-filtered GTFS = ??? MB (Oracle estimates)
  - Target: <400 MB (80% of 500 MB free tier)
  - If exceeds: Upgrade to Pro ($25/month) or optimize schema

Compute:
- Celery task daily: ~30 min processing
  - Railway/Fly.io: Included in base plan ✅

Total Monthly Cost:
- MVP (1K users): $0-5/month (if stay under free tiers)
- Growth (10K users): $5-25/month (likely upgrade Supabase)
```

**Performance Metrics:**
```
Pipeline Runtime:
- Download 227 MB: ~2-5 min (network dependent)
- Parse & filter: ~5-10 min (CPU bound)
- Load to Supabase: ~10-20 min (bulk insert)
- Generate iOS SQLite: ~3-5 min
- Upload to CDN: ~1-2 min
- Total: ~25-40 min

Oracle: Optimize to <30 min target
```

**Oracle Provide:**
- Detailed cost table (0, 1K, 10K users)
- Performance optimization recommendations
- Scaling triggers (when to upgrade storage/compute)

### 7. Monitoring & Alerting

**Question:** How to monitor pipeline health and alert on failures?

**Metrics to Track:**
```python
# After each successful run, log:
{
    "timestamp": "2025-11-12T03:30:00Z",
    "gtfs_version": "20251112",  # From feed_info.txt or ZIP metadata
    "download_time_seconds": 180,
    "processing_time_seconds": 1200,
    "total_rows_loaded": {
        "stops": 2048,
        "routes": 512,
        "trips": 52000,
        "stop_times": 1500000
    },
    "ios_sqlite_size_mb": 18.5,
    "supabase_db_size_mb": 320,
    "validation_passed": true,
    "errors": []
}

# Store in Supabase table: gtfs_sync_log
```

**Alerts:**
```
Trigger alert if:
- Pipeline fails (email/Slack to developer)
- Pipeline takes >60 min (performance degradation)
- Validation checks fail (data quality issue)
- Supabase DB size >450 MB (approaching limit)
- iOS SQLite >25 MB (approaching app size target)

Oracle: Design simple alerting (email via SendGrid free tier?)
```

**Health Dashboard:**
```sql
-- Simple Supabase SQL view for monitoring
CREATE VIEW gtfs_health AS
SELECT
    MAX(timestamp) AS last_sync,
    AVG(total_time_seconds) AS avg_runtime,
    SUM(CASE WHEN validation_passed THEN 1 ELSE 0 END) AS successful_runs,
    COUNT(*) AS total_runs
FROM gtfs_sync_log
WHERE timestamp > NOW() - INTERVAL '30 days';
```

---

## Research Mandate (Oracle's Superpower)

**CRITICAL:** Research real-world GTFS optimization techniques.

### Required Research Activities

1. **GTFS Optimization Techniques:**
   - Search: "GTFS data size reduction techniques"
   - Search: "GTFS stop_times compression"
   - Search: "Mobile app GTFS offline storage optimization"
   - **Goal:** Find proven techniques from production apps

2. **Transit App Architectures:**
   - Search: "TripView architecture" (how they fit in 5.44 MB)
   - Search: "Transit app offline data strategy"
   - Search: "Open source GTFS mobile app GitHub" (citymapper, transitapp)
   - **Goal:** Learn from successful implementations

3. **SQLite Optimization:**
   - Search: "SQLite database size optimization techniques"
   - Search: "SQLite PRAGMA settings for read-heavy workload"
   - Search: "SQLite compression iOS apps"
   - **Goal:** Best practices for mobile SQLite databases

4. **Python GTFS Libraries:**
   - Search: "Python GTFS parsing library comparison"
   - Search: "gtfs-kit vs partridge performance"
   - **Goal:** Choose best library for our use case

### Citation Format

Cite sources for major decisions:
```
Recommendation: Use gtfs-kit library for parsing

Rationale: After comparing gtfs-kit [1], partridge [2], and custom pandas parsing,
gtfs-kit provides best balance of memory efficiency and features for large GTFS
feeds. Used by [list of production apps]. Supports filtering and validation
out-of-the-box.

Sources:
[1] https://github.com/mrcagney/gtfs_kit (1.2K stars, active maintenance)
[2] https://github.com/remix/partridge (comparison benchmark)
```

---

## Expected Output Format

### 1. Pipeline Architecture Diagram
```
[Detailed ASCII or description showing:]

Daily 3 AM Sydney Time (Celery Beat)
    ↓
Download GTFS ZIP (227 MB) from NSW API
    ↓
Validate & Extract to temp directory
    ↓
Parse CSV files (Oracle's recommended library)
    ↓
Filter to Sydney-only data (Oracle's filtering logic)
    ↓
Prune unnecessary fields (Oracle's field list)
    ↓
Load to Supabase PostgreSQL (bulk insert)
    ↓
Run validation checks (Oracle's checklist)
    ↓
Generate optimized iOS SQLite (<20 MB target)
    ↓
Upload to CloudFlare CDN
    ↓
Notify iOS apps (new version available)
    ↓
Log metrics to gtfs_sync_log table
```

### 2. Data Filtering Specification

**SQL Queries:**
```sql
-- Oracle provides exact filtering logic

-- Filter stops to Sydney region only
DELETE FROM stops WHERE stop_lat < -34.5 OR stop_lat > -33.0 OR stop_lon < 150.5 OR stop_lon > 151.5;

-- Filter routes to Sydney agencies only
DELETE FROM routes WHERE agency_id NOT IN ('SydneyTrains', 'SydneyMetro', 'SydneyBuses', 'SydneyFerries');

-- Prune stop_times to next 14 days only
DELETE FROM stop_times WHERE ...;  -- Oracle defines date range logic

-- Oracle: Provide complete filtering script
```

### 3. iOS SQLite Schema

**Complete DDL:**
```sql
-- Oracle provides optimized schema for iOS

CREATE TABLE stops (
    stop_id TEXT PRIMARY KEY,
    stop_name TEXT NOT NULL,
    stop_lat REAL NOT NULL,
    stop_lon REAL NOT NULL,
    wheelchair_boarding INTEGER DEFAULT 0
    -- Oracle: Include only essential fields
) WITHOUT ROWID;  -- SQLite optimization

CREATE INDEX idx_stops_name ON stops(stop_name);
-- Oracle: Define all necessary indexes

PRAGMA page_size = 8192;  -- Oracle determines optimal
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
VACUUM;

-- Expected final size: <20 MB
```

### 4. Python Pipeline Implementation (Pseudocode)

**Detailed pseudocode:**
```python
import gtfs_kit  # Oracle's recommended library
from supabase import create_client

@app.task
def sync_gtfs_static():
    try:
        # Step 1: Download
        gtfs_url = "https://api.transport.nsw.gov.au/v1/gtfs/schedule/..."
        zip_path = download_with_progress(gtfs_url, headers={"Authorization": f"apikey {NSW_API_KEY}"})

        # Step 2: Extract & Parse
        feed = gtfs_kit.read_feed(zip_path, dist_units='km')

        # Step 3: Filter to Sydney
        sydney_feed = filter_to_sydney(feed)  # Oracle defines this function

        # Step 4: Load to Supabase
        load_to_supabase(sydney_feed)

        # Step 5: Validate
        validation_results = validate_gtfs_import()
        if not validation_results['passed']:
            raise ValidationError(validation_results['errors'])

        # Step 6: Generate iOS SQLite
        sqlite_path = generate_ios_sqlite()
        upload_to_cdn(sqlite_path)

        # Step 7: Log success
        log_sync_completion(success=True)

    except Exception as e:
        log_sync_completion(success=False, error=str(e))
        send_alert(f"GTFS sync failed: {e}")
        raise

# Oracle provides detailed implementation for each function
```

### 5. Cost & Size Estimation Table

| Metric | Before Optimization | After Oracle Optimization | Reduction |
|--------|---------------------|---------------------------|-----------|
| Raw GTFS ZIP | 227 MB | 227 MB | 0% (source data) |
| Uncompressed | 500-700 MB | ??? MB | ??% |
| Supabase DB | 500-700 MB | <400 MB | >40% |
| iOS SQLite | N/A | <20 MB | N/A |
| Total App Size | N/A | <35 MB | N/A |

### 6. Validation Checklist

**Complete list:**
```python
VALIDATION_CHECKS = [
    # Oracle provides 15-20 critical checks with expected ranges
    # Format: (check_name, SQL_query, min_expected, max_expected)
]
```

### 7. Monitoring Dashboard Design

**Supabase SQL View:**
```sql
-- Oracle provides complete dashboard queries
CREATE VIEW gtfs_pipeline_health AS ...;
```

---

## Success Criteria

Oracle's solution is successful if:

✅ **App Size:** iOS app stays <50 MB (ideally <35 MB)
✅ **Database Size:** Supabase stays <400 MB (80% of free tier)
✅ **Cost:** Pipeline runs <$5/month
✅ **Performance:** Pipeline completes <30 min daily
✅ **Quality:** Validation checks ensure data integrity
✅ **Research-Backed:** Cites 3+ production GTFS optimization examples
✅ **Practical:** Solo developer can implement in 2 weeks
✅ **Complete:** Includes SQL scripts, Python pseudocode, cost estimates

---

## Submission Instructions

1. **Attach:** `SYSTEM_OVERVIEW.md` (full context)
2. **Paste:** This prompt in its entirety
3. **Request:** "Research GTFS optimization techniques and design complete ingestion pipeline"
4. **Expect:** 3-5 hour turnaround (includes research + detailed design)

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
