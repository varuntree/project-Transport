# Checkpoint 6: iOS Project Structure

## Goal
Xcode project with SwiftUI, iOS 16.0 deployment target, directory layout per DEVELOPMENT_STANDARDS.

## Approach

### Backend Implementation
None

### iOS Implementation

**Steps:**
1. Create new Xcode project:
   - File → New → Project
   - iOS → App
   - Product Name: SydneyTransit
   - Organization Identifier: com.sydneytransit
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None
   - Location: `/Users/varunprasad/code/prjs/prj_transport/`

2. Set deployment target:
   - Project settings → General
   - Minimum Deployments: iOS 16.0

3. Create directory structure:
   ```
   SydneyTransit/
   ├── SydneyTransitApp.swift
   ├── Core/
   │   └── Utilities/
   ├── Features/
   │   └── Home/
   └── Resources/
   ```

4. Create `.gitignore` at iOS root:
   ```
   # Xcode
   xcuserdata/
   DerivedData/
   *.xcworkspace/xcuserdata/

   # Config (contains secrets)
   Config.plist

   # Build
   build/
   *.ipa
   *.dSYM.zip

   # Swift Package Manager
   .swiftpm/
   .build/
   ```

5. Delete default ContentView.swift (will create HomeView later)

**Critical constraints:**
- Must use SwiftUI App lifecycle (not UIKit AppDelegate)
- Deployment target MUST be iOS 16.0 (not 17.0)
- Folder structure matches DEVELOPMENT_STANDARDS.md:L733-745

### iOS Implementation
Complete Xcode project creation as described above.

## Design Constraints
- SwiftUI App lifecycle only
- iOS 16.0 minimum (enables ObservableObject compatibility, see iOS research)
- Directory structure per DEVELOPMENT_STANDARDS.md:L733-745
- .gitignore must exclude Config.plist (contains secrets)

## Risks
- Xcode version incompatibility → Use Xcode 15+
  - Mitigation: Check Xcode version in validation
- Wrong deployment target → Set to 16.0 exactly
  - Mitigation: Double-check in project settings

## Validation
```bash
open /Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit.xcodeproj
# Expected: Xcode opens project

# In Xcode:
# 1. Press Cmd+B (build)
# 2. Expected: Build succeeds (no errors or warnings)
# 3. Check Project Settings → General → Minimum Deployments = iOS 16.0
```

## References for Subagent
- iOS structure: DEVELOPMENT_STANDARDS.md:L733-745
- iOS App Spec: IOS_APP_SPECIFICATION.md:Section 2

## Estimated Complexity
**simple** - Standard Xcode project creation
