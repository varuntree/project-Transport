#!/usr/bin/env python3
"""Generate iOS SQLite bundle from Supabase.

Generates gtfs.db → var/data/gtfs.db, then copies to iOS Resources.
"""

import sys
import os
import shutil
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.ios_db_generator import generate_ios_db

# iOS bundle destination
IOS_BUNDLE_PATH = Path(__file__).resolve().parent.parent.parent / "SydneyTransit" / "SydneyTransit" / "Resources" / "gtfs.db"

def main():
    print("Starting iOS SQLite generation...")
    print("This will query Supabase pattern tables and generate gtfs.db")
    print("Expected duration: 30-60 seconds\n")

    try:
        # Generate iOS database
        result = generate_ios_db()

        if result["status"] == "success":
            src_path = result["file_path"]
            print(f"\n✅ iOS database generated successfully!")
            print(f"   Path: {src_path}")
            print(f"   Size: {result['file_size_mb']} MB")
            print(f"   Stops: {result['row_counts']['stops']}")
            print(f"   Routes: {result['row_counts']['routes']}")
            print(f"   Patterns: {result['row_counts']['patterns']}")
            print(f"   Trips: {result['row_counts']['trips']}")

            # Copy to iOS Resources
            print(f"\nCopying to iOS bundle: {IOS_BUNDLE_PATH}")
            os.makedirs(IOS_BUNDLE_PATH.parent, exist_ok=True)
            shutil.copy2(src_path, IOS_BUNDLE_PATH)
            print(f"✅ Copied to iOS bundle")

            print("\n🎉 iOS bundle ready!")
            print("Next: Open Xcode and verify the iOS app sees the updated data")

        else:
            print(f"❌ Generation failed: {result}")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
