# Bug: Xcode Build Failure - Incorrect File References for Departures and Trip Features

## Bug Description
Xcode build fails with error: "Build input files cannot be found: '/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/DeparturesViewModel.swift', '/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/DeparturesView.swift'".

The files exist in the correct location (`SydneyTransit/SydneyTransit/Features/Departures/`) but Xcode project file references point to incorrect paths (missing the nested `SydneyTransit/Features/Departures/` directory structure).

## Problem Statement
During Phase 2.1 implementation, the AI agents created iOS feature files (Departures, Trips) but the Xcode `project.pbxproj` file references were not properly configured with the full relative paths from the project root. This causes the Swift compiler to fail when building because it cannot locate the source files.

## Solution Statement
Fix the Xcode project file (`project.pbxproj`) to correctly reference all Phase 2.1 feature files with their proper relative paths. Specifically:
- DeparturesView.swift: `SydneyTransit/Features/Departures/DeparturesView.swift`
- DeparturesViewModel.swift: `SydneyTransit/Features/Departures/DeparturesViewModel.swift`
- TripDetailsView.swift: `SydneyTransit/Features/Trips/TripDetailsView.swift`
- TripDetailsViewModel.swift: `SydneyTransit/Features/Trips/TripDetailsViewModel.swift`
- Trip.swift: `SydneyTransit/Data/Models/Trip.swift`
- TripRepository.swift: `SydneyTransit/Data/Repositories/TripRepository.swift`

## Steps to Reproduce
1. Navigate to `SydneyTransit` directory
2. Run `xcodebuild -scheme SydneyTransit -sdk iphonesimulator build`
3. Build fails with error: "Build input files cannot be found: '/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/DeparturesViewModel.swift', '/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/DeparturesView.swift'"

## Root Cause Analysis
The root cause is incorrect `path` attributes in the `PBXFileReference` entries within `SydneyTransit.xcodeproj/project.pbxproj`. The file references were created during automated implementation but specify only filenames (`path = DeparturesView.swift`) instead of relative paths from the group/project root (`path = SydneyTransit/Features/Departures/DeparturesView.swift`).

Xcode uses these paths to locate source files during compilation. When the path is just a filename without the directory structure, Xcode searches in the wrong location (project root instead of nested feature directories).

## Relevant Files
Use these files to fix the bug:

- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit.xcodeproj/project.pbxproj` - Xcode project configuration file containing file references with incorrect paths. Need to update `PBXFileReference` entries for:
  - `0DEF813EDD13476B8B426268` (DeparturesView.swift)
  - `5C7D78E67F5740468A80CF2B` (DeparturesViewModel.swift)
  - Plus all Trip feature file references (TripDetailsView.swift, TripDetailsViewModel.swift, Trip.swift, TripRepository.swift)

- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Departures/DeparturesView.swift` - Actual file location (correct)
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Departures/DeparturesViewModel.swift` - Actual file location (correct)
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Trips/TripDetailsView.swift` - Actual file location (correct)
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Trips/TripDetailsViewModel.swift` - Actual file location (correct)
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Trip.swift` - Actual file location (correct)
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Repositories/TripRepository.swift` - Actual file location (correct)

## Step by Step Tasks

### Find All Incorrect File References
- Read `SydneyTransit.xcodeproj/project.pbxproj`
- Identify all `PBXFileReference` entries for Departures and Trips feature files
- Note their UUIDs and current path values
- Verify which files have incorrect paths (missing directory structure)

### Update PBXFileReference Paths
- For each incorrect file reference in `project.pbxproj`:
  - DeparturesView.swift: Change `path = DeparturesView.swift;` to `path = "SydneyTransit/Features/Departures/DeparturesView.swift";`
  - DeparturesViewModel.swift: Change `path = DeparturesViewModel.swift;` to `path = "SydneyTransit/Features/Departures/DeparturesViewModel.swift";`
  - TripDetailsView.swift: Change path to `"SydneyTransit/Features/Trips/TripDetailsView.swift";`
  - TripDetailsViewModel.swift: Change path to `"SydneyTransit/Features/Trips/TripDetailsViewModel.swift";`
  - Trip.swift: Change path to `"SydneyTransit/Data/Models/Trip.swift";`
  - TripRepository.swift: Change path to `"SydneyTransit/Data/Repositories/TripRepository.swift";`
- Ensure quotes are present if paths contain spaces or special characters
- Preserve all other attributes (`lastKnownFileType`, `sourceTree`, etc.)

### Verify File Existence
- For each updated path, verify the file actually exists at that location using `ls -la` commands
- Confirm no typos in directory names (Features vs Feature, Departures vs Departure, etc.)

### Run Validation Commands
- Execute all validation commands from the "Validation Commands" section below
- Verify build succeeds with zero errors
- Confirm no warnings about missing file references

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.

- `ls -la /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Departures/` - Verify Departures files exist
- `ls -la /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Trips/` - Verify Trips files exist
- `ls -la /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Trip.swift` - Verify Trip model exists
- `ls -la /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Repositories/TripRepository.swift` - Verify TripRepository exists
- `grep -A 1 "DeparturesView.swift" /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit.xcodeproj/project.pbxproj` - Verify path updated correctly in project file
- `grep -A 1 "DeparturesViewModel.swift" /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit.xcodeproj/project.pbxproj` - Verify path updated correctly in project file
- `cd /Users/varunprasad/code/prjs/prj_transport/SydneyTransit && xcodebuild -scheme SydneyTransit -sdk iphonesimulator clean build 2>&1 | grep "BUILD SUCCEEDED"` - Verify Xcode build succeeds
- `cd /Users/varunprasad/code/prjs/prj_transport/SydneyTransit && xcodebuild -scheme SydneyTransit -sdk iphonesimulator build 2>&1 | grep -c "error:"` - Verify zero build errors (output should be 0)

## Notes
- This is a project configuration bug, not a code bug - all Swift source files are correct
- The bug was introduced during Phase 2.1 automated implementation when subagents created files but didn't properly update Xcode project references
- Similar issues may exist for other Phase 2.1 files - scan entire `project.pbxproj` for file references with path-only values (no directory structure)
- Alternative fix: Use Xcode GUI to re-add files (File → Add Files to "SydneyTransit"), but programmatic fix is faster and more reliable
- After fixing, the build should succeed and all Phase 2.1 features (stop search icons, real departures, trip details, route filters, A-Z navigation) should be testable in simulator
