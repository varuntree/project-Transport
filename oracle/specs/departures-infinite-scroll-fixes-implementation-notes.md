## Implementation Notes (auto-inferred tasks)

1. **Scroll sentinel behavior (DeparturesView)**  
   - Introduced `ScrollOffsetPreferenceKey` + coordinate space tracking so past sentinel only fires after the user scrolls upward.  
   - Added `hasMorePast`/`hasMoreFuture` flags to avoid redundant fetches and throttle onAppear re-triggers.
   - Swapped the countdown text to `minutesUntilText` to display “X min ago”, “Now”, or “N min” depending on the real-time delta.

2. **ViewModel adjustments**  
   - Kept existing `loadPast`/`loadFuture` logic but now exposes published `hasMore*` so the view can hide sentinels when no more data is available.
   - Retained timer-based refresh but ensured fresh pages replace the list cleanly while preserving cursors/dedup.

3. **Occupancy logging & testing**  
   - Logged vehicle-position blob metadata and sample occupancy in `realtime_service.py`; added departure occupancy logging at the API level; instrumented SwiftUI to log occupancy status per row.  
   - Added a unit test file covering `Departure.occupancyIcon` mapping to guard symbol/label expectations.

4. **Trip map logging & graceful partial rendering**  
   - Logged stop-by-stop coordinate health plus a high-level `trip_coords_summary` when building trip details.  
   - TripDetailsView now logs map visibility counts and still shows a partial route warning when fewer than total stops have coordinates. Map rendering already filters nil coordinates before drawing annotations/polyline.

5. **Validation blockers**  
   - Redis/Postgres/Celery checks blocked earlier because the CLI lacked `redis-cli`, `psql`, and `celery` binaries. A `.venv` was created to install Python’s `redis` client for future verification once binaries or connection info are available.

