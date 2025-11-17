# Checkpoint 1: Fix Departures Time Filtering

## Goal
Show only future departures (next 10-20 services), hide past times. Different departures per stop.

## Approach

### Backend Implementation
- Edit `backend/app/services/realtime_service.py:139-162` (get_stop_departures function)
- Add WHERE clause filter: `AND ps.departure_offset_secs >= :time_secs`
- Calculate time_secs from current Sydney time: `(now.hour * 3600) + (now.minute * 60) + now.second`
- Use bind parameter `:time_secs` (not f-string)
- Optional: Add `LIMIT 20` to prevent oversized responses
- Verify calendar query already uses `now_date` for service day lookup (no changes needed)

### iOS Implementation
None (backend fix only)

## Design Constraints
- Follow DEVELOPMENT_STANDARDS.md SQL patterns (bind parameters, no f-strings)
- Must handle midnight rollover (00:00-02:00 departures show prev day's late services)
- Use Sydney timezone for time calculation (not server UTC)
- Maintain existing departure structure (route, trip, headsign, platform, offset_secs)

## Risks
- Midnight rollover edge case (services running past midnight)
  - Mitigation: Query uses calendar.date = now_date, handles service day correctly
- Timezone mismatch (server UTC vs Sydney)
  - Mitigation: Use `now` from API request timezone context

## Validation
```bash
# Backend must be running
cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && curl "http://localhost:8000/api/v1/stops/200060/departures?limit=20"
# Expected: 10-20 departures, all departure_offset_secs >= current_time_secs
# Verify different results for different stops (not hardcoded)
```

## References for Subagent
- Exploration report: `affected_systems[0]` → Departures time filtering
- Standards: DEVELOPMENT_STANDARDS.md → SQL patterns (bind parameters)
- Architecture: BACKEND_SPECIFICATION.md → Departures endpoint
- File location: backend/app/services/realtime_service.py:139-162

## Estimated Complexity
Simple - Single WHERE clause addition, 5 min implementation + 5 min validation
