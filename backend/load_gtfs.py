#!/usr/bin/env python3
"""
Manual GTFS load script.
Runs GTFS download + parse + load pipeline.
"""

import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.tasks.gtfs_static_sync import load_gtfs_static

if __name__ == "__main__":
    print("Starting GTFS load...")
    print("This will download ~200MB from NSW API, parse, and load to Supabase.")
    print("Expected duration: 3-5 minutes\n")

    try:
        result = load_gtfs_static()
        print("\n✅ GTFS Load Complete!")
        print(f"Duration: {result['duration_ms'] / 1000:.1f}s")
        print(f"Stops: {result['counts']['stops']}")
        print(f"Routes: {result['counts']['routes']}")
        print(f"Patterns: {result['counts']['patterns']}")
        print(f"Trips: {result['counts']['trips']}")
        print(f"Validation: {'PASSED' if result['validation']['passed'] else 'FAILED'}")

    except Exception as e:
        print(f"\n❌ GTFS Load Failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
