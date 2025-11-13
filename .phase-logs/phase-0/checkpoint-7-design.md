# Checkpoint 7: iOS Dependencies (SPM)

## Goal
Add Supabase Swift + swift-log via Swift Package Manager, packages resolve successfully.

## Approach

### Backend Implementation
None

### iOS Implementation

**Add packages via Xcode:**

1. **supabase-swift:**
   - File → Add Package Dependencies
   - URL: `https://github.com/supabase/supabase-swift.git`
   - Dependency Rule: "Up to Next Major Version" starting from 2.0.0
   - Add to target: SydneyTransit
   - Products: Auth, Functions, PostgREST, Realtime, Storage

2. **swift-log:**
   - File → Add Package Dependencies
   - URL: `https://github.com/apple/swift-log.git`
   - Dependency Rule: "Up to Next Major Version" starting from 1.5.3
   - Add to target: SydneyTransit
   - Products: Logging

3. **Resolve packages:**
   - File → Packages → Resolve Package Versions
   - Wait for resolution to complete

**Verify in code:**
Create test import in `SydneyTransitApp.swift`:
```swift
import Supabase
import Logging
```
Build (Cmd+B) - should succeed without "missing module" errors.

### iOS Implementation
Complete SPM package addition as described above.

## Design Constraints
- Use "Up to Next Major Version" for stability
- supabase-swift must be 2.x (latest stable)
- swift-log must be 1.5.3+
- Both packages must resolve without conflicts

## Risks
- Package resolution fails → Network issue or incompatible versions
  - Mitigation: Retry resolution, check Xcode console for errors
- supabase-swift pulls many dependencies → Longer build time
  - Mitigation: Expected, not a blocker

## Validation
```bash
# In Xcode:
# 1. Project Navigator → Package Dependencies section shows:
#    - supabase-swift (2.x)
#    - swift-log (1.5.3+)
# 2. Build project (Cmd+B)
# 3. Expected: Build succeeds, no "missing module Supabase" or "missing module Logging" errors
```

## References for Subagent
- Dependencies: IOS_APP_SPECIFICATION.md:Section 3
- Supabase Swift: https://github.com/supabase/supabase-swift
- swift-log: https://github.com/apple/swift-log

## Estimated Complexity
**simple** - Standard SPM package addition via Xcode UI
