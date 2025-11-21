#!/usr/bin/env python3
"""
Update start_time_secs in trips table from existing GTFS data.
Parses stop_times.txt to calculate trip start times and updates DB.
"""

import csv
from collections import defaultdict
import os
from pathlib import Path
from supabase import create_client, Client

# Get Supabase credentials from environment
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERROR: Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Base directory for generated GTFS data
VAR_DIR = Path(os.getenv("VAR_DIR", Path(__file__).resolve().parent.parent / "var")).resolve()
GTFS_DIR = VAR_DIR / "data" / "gtfs-downloads"

def time_to_seconds(time_str):
    """Convert HH:MM:SS to seconds since midnight"""
    try:
        parts = time_str.strip().split(":")
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds = int(parts[2])
        return hours * 3600 + minutes * 60 + seconds
    except:
        return None

print("Step 1: Reading stop_times from GTFS files...")

# Read stop_times for all modes to find trip start times
trip_start_times = {}  # {trip_id: start_time_secs}
modes = ["sydneytrains", "metro", "buses", "lightrail", "mff", "sydneyferries"]

for mode in modes:
    filepath = GTFS_DIR / mode / "stop_times.txt"
    if not os.path.exists(filepath):
        print(f"  Skipping {mode} (file not found)")
        continue

    print(f"  Processing {mode}...")
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            trip_id = f"{mode}_{row['trip_id']}"  # Prefixed in parser
            stop_sequence = int(row['stop_sequence'])

            # First stop (stop_sequence=1 usually, but check for min)
            if stop_sequence == 1 or trip_id not in trip_start_times:
                start_time = time_to_seconds(row['departure_time'])
                if start_time is not None:
                    if trip_id not in trip_start_times or stop_sequence < trip_start_times[trip_id][1]:
                        trip_start_times[trip_id] = (start_time, stop_sequence)

# Extract just the start times
trip_start_times = {tid: start for tid, (start, seq) in trip_start_times.items()}

print(f"\nStep 2: Found start times for {len(trip_start_times)} trips")
print(f"  Sample: {list(trip_start_times.items())[:3]}")

# Batch update Supabase
print("\nStep 3: Updating trips table in Supabase...")
BATCH_SIZE = 1000
trip_ids = list(trip_start_times.keys())
updated_count = 0

for i in range(0, len(trip_ids), BATCH_SIZE):
    batch_ids = trip_ids[i:i+BATCH_SIZE]
    batch_updates = []

    for trip_id in batch_ids:
        batch_updates.append({
            "trip_id": trip_id,
            "start_time_secs": trip_start_times[trip_id]
        })

    # Upsert batch
    try:
        supabase.table("trips").upsert(batch_updates).execute()
        updated_count += len(batch_updates)
        print(f"  Updated {updated_count}/{len(trip_ids)} trips...")
    except Exception as e:
        print(f"  Error updating batch {i//BATCH_SIZE}: {e}")
        break

print(f"\n✅ Updated {updated_count} trips with start_time_secs")

# Verify
print("\nStep 4: Verifying update...")
result = supabase.table("trips").select("start_time_secs").not_.is_("start_time_secs", "null").limit(5).execute()
if result.data:
    print(f"  Sample start_time_secs values: {[r['start_time_secs'] for r in result.data]}")
else:
    print("  WARNING: No trips have start_time_secs set!")
