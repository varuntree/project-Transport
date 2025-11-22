import os
import sys
import asyncio
from datetime import datetime
import pytz

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings
from app.db.supabase_client import get_supabase

async def check_schedule():
    supabase = get_supabase()
    
    sydney_tz = pytz.timezone('Australia/Sydney')
    now = datetime.now(sydney_tz)
    today_str = now.strftime("%Y-%m-%d")
    
    print(f"Checking schedule for: {today_str}")
    
    # 1. Check calendar for active services
    print("\n--- Calendar Check ---")
    cal_query = f"""
    SELECT service_id, start_date, end_date 
    FROM calendar 
    WHERE start_date <= '{today_str}' AND end_date >= '{today_str}'
    LIMIT 5
    """
    res = supabase.rpc("exec_raw_sql", {"query": cal_query}).execute()
    services = res.data or []
    print(f"Active services found: {len(services)} (showing first 5)")
    for s in services:
        print(s)
        
    if not services:
        print("CRITICAL: No active services found for today in calendar!")
        return

    # 2. Check trips for one service
    service_id = services[0]['service_id']
    print(f"\n--- Trips Check (for service {service_id}) ---")
    trip_query = f"SELECT trip_id, route_id FROM trips WHERE service_id = '{service_id}' LIMIT 5"
    res = supabase.rpc("exec_raw_sql", {"query": trip_query}).execute()
    trips = res.data or []
    print(f"Trips found: {len(trips)}")
    for t in trips:
        print(t)

    if not trips:
        print("CRITICAL: No trips found for active service!")
        return

    # 3. Check pattern_stops for one trip
    trip_id = trips[0]['trip_id']
    print(f"\n--- Pattern Stops Check (for trip {trip_id}) ---")
    # Get pattern_id for trip
    pat_query = f"SELECT pattern_id FROM trips WHERE trip_id = '{trip_id}'"
    res = supabase.rpc("exec_raw_sql", {"query": pat_query}).execute()
    if not res.data:
        print("Trip has no pattern!")
        return
    pattern_id = res.data[0]['pattern_id']
    
    ps_query = f"""
    SELECT stop_id, stop_sequence, departure_offset_secs 
    FROM pattern_stops 
    WHERE pattern_id = '{pattern_id}' 
    ORDER BY stop_sequence 
    LIMIT 5
    """
    res = supabase.rpc("exec_raw_sql", {"query": ps_query}).execute()
    stops = res.data or []
    print(f"Stops found on pattern {pattern_id}: {len(stops)}")
    for s in stops:
        print(s)
        
    # 4. Check departures for this stop
    if stops:
        stop_id = stops[0]['stop_id']
        print(f"\n--- Departures Check for Stop {stop_id} ---")
        # Use the exact query logic from realtime_service
        # Assuming now is start time
        time_secs_local = int((now - now.replace(hour=0, minute=0, second=0, microsecond=0)).total_seconds())
        
        query = f"""
        SELECT
            t.trip_id,
            (t.start_time_secs + ps.departure_offset_secs) as actual_departure_secs
        FROM pattern_stops ps
        JOIN patterns p ON ps.pattern_id = p.pattern_id
        JOIN trips t ON t.pattern_id = p.pattern_id
        JOIN calendar c ON t.service_id = c.service_id
        WHERE ps.stop_id = '{stop_id}'
          AND c.start_date <= '{today_str}'
          AND c.end_date >= '{today_str}'
          AND (t.start_time_secs + ps.departure_offset_secs) >= {time_secs_local}
        ORDER BY (t.start_time_secs + ps.departure_offset_secs) ASC
        LIMIT 5
        """
        res = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        deps = res.data or []
        print(f"Upcoming departures found via SQL: {len(deps)}")
        for d in deps:
            print(d)

if __name__ == "__main__":
    asyncio.run(check_schedule())
