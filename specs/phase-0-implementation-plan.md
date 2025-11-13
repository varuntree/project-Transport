# Phase 0 Implementation Plan

**Phase:** Foundation (Local Dev Environment)
**Duration:** Week 1-2
**Complexity:** Simple

---

## Goals

- FastAPI backend running locally with Supabase/Redis connected
- iOS SwiftUI app launching in simulator
- Git repo with proper ignore rules
- Hello-world integration test (iOS → Backend)
- Pure foundation verification before Phase 1 GTFS complexity

---

## Key Technical Decisions

1. **Singleton database clients (Supabase, Redis)**
   - Rationale: FastAPI Depends() pattern + global singletons prevent connection pool exhaustion, enable connection reuse across requests
   - Reference: DEVELOPMENT_STANDARDS.md:Section 2 (L203-300)
   - Critical constraint: MUST use get_supabase()/get_redis() via Depends(), never instantiate directly in routes

2. **Structured logging (structlog JSON)**
   - Rationale: Solo dev needs parseable logs for debugging; JSON format enables grep/jq queries, future log aggregation
   - Reference: DEVELOPMENT_STANDARDS.md:Section 4 (L554-631), PHASE_0:L211-216
   - Critical constraint: NEVER log PII (email, name, tokens); always use structured events like logger.info('stop_fetched', stop_id='12345')

3. **MVVM + Coordinator pattern (iOS)**
   - Rationale: SwiftUI-native ObservableObject (iOS 16 compat), testable ViewModels, protocol-based repositories enable offline-first + mock testing
   - Reference: DEVELOPMENT_STANDARDS.md:Section 6 (L747-905), IOS_APP_SPECIFICATION.md:Section 2
   - Critical constraint: ViewModels MUST be @MainActor, repositories MUST use protocols, coordinators handle all navigation
   - iOS 16 compatibility: Use ObservableObject (not @Observable macro) per `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`

4. **Railway public Redis URL (not private .railway.internal)**
   - Rationale: Private URLs only work inside Railway network; local dev requires public URL access
   - Reference: PHASE_0_FOUNDATION.md:L88-105
   - Critical constraint: MUST use REDIS_PUBLIC_URL with external hostname (rlwy.net:PORT), NOT REDIS_PRIVATE_URL

5. **Python 3.11+, iOS 16+ minimum**
   - Rationale: Python 3.11 has 25% faster startup + match/case syntax; iOS 16 enables SwiftUI Live Activities (Phase 1.5)
   - Reference: SYSTEM_OVERVIEW.md:Section 5, PHASE_0_FOUNDATION.md:L58-62
   - Critical constraint: Pin Python 3.11 in requirements.txt, set iOS deployment target to 16.0 in Xcode

---

## Implementation Checkpoints

### Checkpoint 1: Backend Project Structure

**Goal:** FastAPI project with proper directory layout per DEVELOPMENT_STANDARDS

**Backend Work:**
- Create backend/app/ directory tree (api/v1, db, utils, tasks, models)
- Create backend/requirements.txt (fastapi==0.104.1, uvicorn, celery, redis, supabase, structlog)
- Create backend/.env.example (safe template with dummy values)
- Create backend/.gitignore (exclude .env, __pycache__, venv/)

**iOS Work:** None

**Design Constraints:**
- Follow DEVELOPMENT_STANDARDS.md Section 1 for directory structure
- Use pinned versions in requirements.txt (no "latest")
- .env.example must have ALL vars from config.py, but with safe dummy values

**Validation:**
```bash
ls -R backend/
# Expected: app/api/v1, app/db, app/utils, app/tasks, app/models, requirements.txt, .env.example, .gitignore
```

**References:**
- Structure: DEVELOPMENT_STANDARDS.md:L36-82
- Dependencies: BACKEND_SPECIFICATION.md:Section 1

---

### Checkpoint 2: Backend Configuration

**Goal:** Environment variables loaded via Pydantic Settings, validates required vars

**Backend Work:**
- Implement backend/app/config.py (Pydantic BaseSettings, load .env.local)
- Validate SUPABASE_URL, SUPABASE_SERVICE_KEY, REDIS_URL, NSW_API_KEY
- Raise clear error if any required var missing

**iOS Work:** None

**Design Constraints:**
- Use Pydantic BaseSettings with `env_file='.env.local'`
- All vars must have type hints (str, int, HttpUrl)
- Error messages must guide user to .env.example

**Validation:**
```bash
python -c 'from app.config import settings; print(settings.SUPABASE_URL)'
# Expected: Prints URL (not None), no import errors
```

**References:**
- Pattern: DEVELOPMENT_STANDARDS.md:L940-963

---

### Checkpoint 3: Database Clients (Supabase + Redis)

**Goal:** Singleton clients working, connection test functions pass

**Backend Work:**
- Implement backend/app/db/supabase_client.py (singleton, get_supabase() via Depends())
- Implement backend/app/db/redis_client.py (async Redis, get_redis() via Depends())
- Add test_connection() methods to both (simple query/PING)

**iOS Work:** None

**Design Constraints:**
- Supabase: Use supabase-py library, create_client() once globally
- Redis: Use redis-py async client (redis.asyncio), connection pool with max_connections=10
- FastAPI: Expose via Depends() for dependency injection

**Validation:**
```bash
python -c 'import asyncio; from app.db.redis_client import get_redis; asyncio.run(get_redis().ping())'
# Expected: True (Redis PING successful)
```

**References:**
- Pattern: DEVELOPMENT_STANDARDS.md:L203-260 (Supabase), L266-299 (Redis)

---

### Checkpoint 4: Structured Logging

**Goal:** JSON logs with timestamp, level, event, no PII

**Backend Work:**
- Implement backend/app/utils/logging.py (structlog config per DEVELOPMENT_STANDARDS Section 4)
- Configure JSON processor, TimeStamper(fmt='iso'), add_log_level
- Test: logger.info('server_started', port=8000) outputs valid JSON

**iOS Work:** None

**Design Constraints:**
- Use structlog with JSONRenderer()
- Never log PII: email, name, tokens, full request bodies
- Always use event-driven logging: logger.info('stop_fetched', stop_id='12345', duration_ms=45)

**Validation:**
```bash
# Run backend, check console output is parseable JSON
uvicorn app.main:app --reload
# Expected: {"timestamp": "2025-11-13T10:30:45.123Z", "level": "info", "event": "server_started", "port": 8000}
```

**References:**
- Pattern: DEVELOPMENT_STANDARDS.md:L556-596

---

### Checkpoint 5: FastAPI Hello World

**Goal:** Server starts, /health and / endpoints return 200, logs show startup events

**Backend Work:**
- Implement backend/app/main.py (FastAPI instance, CORS, startup event)
- Add GET /health endpoint (test DB + Redis connections, return 200 if both work)
- Add GET / endpoint (return {"message": "Sydney Transit API", "version": "0.1.0"})
- Startup event: test Supabase + Redis connections, log 'server_started', 'db_connected', 'redis_connected'

**iOS Work:** None

**Design Constraints:**
- Use FastAPI lifespan event for async startup (not deprecated @app.on_event)
- /health must test actual connections (not just "return 200")
- All responses use API envelope: {"data": {...}, "meta": {}}

**Validation:**
```bash
curl http://localhost:8000/health
# Expected: 200 {"data": {"status": "healthy", "services": {"db": "connected", "cache": "connected"}}, "meta": {}}
```

**References:**
- API envelope: DEVELOPMENT_STANDARDS.md:L360-411
- Health check: BACKEND_SPECIFICATION.md:Section 2.1

---

### Checkpoint 6: iOS Project Structure

**Goal:** Xcode project with SwiftUI, minimum iOS 16, proper directory layout

**Backend Work:** None

**iOS Work:**
- Create SydneyTransit.xcodeproj in Xcode 15+
- Set deployment target iOS 16.0, SwiftUI lifecycle
- Create directory structure: Core/Utilities, Features/Home, Resources
- Add .gitignore (exclude xcuserdata/, DerivedData/, Config.plist)

**Design Constraints:**
- Use SwiftUI App lifecycle (not UIKit AppDelegate)
- Deployment target must be exactly iOS 16.0 (not 17.0)
- Folder structure must match DEVELOPMENT_STANDARDS.md Section 6

**Validation:**
```bash
open SydneyTransit.xcodeproj
# Expected: Xcode opens, project builds without errors (Cmd+B)
```

**References:**
- Structure: DEVELOPMENT_STANDARDS.md:L733-745
- iOS App Spec: IOS_APP_SPECIFICATION.md:Section 2

---

### Checkpoint 7: iOS Dependencies (SPM)

**Goal:** Supabase Swift + swift-log added, packages resolve

**Backend Work:** None

**iOS Work:**
- Add Swift Package: supabase-swift (https://github.com/supabase/supabase-swift.git, version 2.0.0+)
- Add Swift Package: swift-log (https://github.com/apple/swift-log.git, version 1.5.3+)
- Resolve packages (File → Packages → Resolve Package Versions)

**Design Constraints:**
- Use exact version constraints (not "Up to Next Major")
- Wait for package resolution before proceeding

**Validation:**
```bash
# Xcode shows packages in Project Navigator under 'Swift Packages', no resolution errors
# Build project (Cmd+B) - should succeed without "missing module" errors
```

**References:**
- Dependencies: IOS_APP_SPECIFICATION.md:Section 3

---

### Checkpoint 8: iOS Configuration

**Goal:** Config.plist loaded, exposes API_BASE_URL and Supabase credentials

**Backend Work:** None

**iOS Work:**
- Create SydneyTransit/Config.plist (API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY, LOG_LEVEL)
- Implement Core/Utilities/Constants.swift (read Config.plist, expose as static properties)
- Validate: Config.apiBaseURL returns 'http://localhost:8000/api/v1'

**Design Constraints:**
- Config.plist must NOT be committed to git (.gitignore it)
- Create Config-Example.plist as safe template (commit this)
- Constants.swift must fail gracefully if Config.plist missing

**Validation:**
```swift
// Add breakpoint in Constants.swift
print(Config.apiBaseURL)
// Expected: "http://localhost:8000/api/v1"
```

**References:**
- Pattern: DEVELOPMENT_STANDARDS.md:L966-1009

---

### Checkpoint 9: iOS Logger

**Goal:** swift-log configured, logs to console with metadata

**Backend Work:** None

**iOS Work:**
- Implement Core/Utilities/Logger.swift (extension Logger { static let app = Logger(label: 'com.sydneytransit.app') })
- Test: Logger.app.info("App launched") appears in Xcode console

**Design Constraints:**
- Use swift-log Logger type (not os.Logger or print())
- Label format: reverse-DNS com.sydneytransit.<module>

**Validation:**
```bash
# Run app in simulator, Xcode console shows:
# 2025-11-13T10:30:45+1100 info: App launched
```

**References:**
- Pattern: DEVELOPMENT_STANDARDS.md:L600-619

---

### Checkpoint 10: iOS Home Screen

**Goal:** Simple SwiftUI view displays, app launches without crashes

**Backend Work:** None

**iOS Work:**
- Create Features/Home/HomeView.swift (NavigationStack with 'Sydney Transit' title, 'Phase 0: Foundation' subtitle)
- Implement SydneyTransitApp.swift (set HomeView as root, log 'App launched' on startup)
- Run in iPhone 15 Pro simulator

**Design Constraints:**
- Use NavigationStack (not deprecated NavigationView)
- HomeView must be @MainActor-isolated (ViewModels will require this)
- iOS 16 compatibility: Use ObservableObject for future ViewModels (see `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`)

**Validation:**
```bash
# Cmd+R in Xcode
# Expected: App launches, displays 'Sydney Transit' title, no crashes, console shows 'App launched' log
```

**References:**
- iOS Research: `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`

---

### Checkpoint 11: Integration Test (iOS → Backend)

**Goal:** iOS app fetches data from local backend, displays message

**Backend Work:**
- Backend must be running (uvicorn app.main:app --reload)

**iOS Work:**
- Add @State var apiStatus = "Not checked" to HomeView
- Add .onAppear { Task { ... URLSession.shared.data(from: Config.apiBaseURL/) ... apiStatus = json['message'] } }
- Display apiStatus in HomeView Text() component

**Design Constraints:**
- Use URLSession with async/await (not completion handlers)
- Handle errors gracefully (display error message if backend unreachable)
- Parse JSON response manually (no Codable needed for simple test)

**Validation:**
```bash
# 1. Start backend: uvicorn app.main:app --reload
# 2. Run iOS app (Cmd+R)
# Expected: HomeView displays "Sydney Transit API" (fetched from GET / endpoint)
```

**References:**
- Integration: INTEGRATION_CONTRACTS.md:Section 1 (REST API)

---

## Acceptance Criteria

**Backend:**
- [ ] uvicorn app.main:app --reload starts without errors, logs 'server_started' event in JSON
- [ ] curl http://localhost:8000/health returns 200 with {"data": {"status": "healthy", "services": {"db": "connected", "cache": "connected"}}, "meta": {}}
- [ ] curl http://localhost:8000/ returns 200 with {"data": {"message": "Sydney Transit API", "version": "0.1.0"}, "meta": {}}
- [ ] Console output is valid JSON with timestamp, level, event fields (no plaintext logs)
- [ ] python -c 'from app.config import settings; print(settings.SUPABASE_URL)' prints URL without error

**iOS:**
- [ ] open SydneyTransit.xcodeproj in Xcode, project builds without errors or warnings
- [ ] Select iPhone 15 Pro simulator, press Cmd+R, app launches and displays 'Sydney Transit' title
- [ ] Xcode console shows 'App launched' log entry with timestamp
- [ ] Add breakpoint in Constants.swift, verify Config.apiBaseURL = 'http://localhost:8000/api/v1'

**Integration:**
- [ ] Backend running at localhost:8000, iOS app HomeView displays 'Sydney Transit API' message fetched from GET / endpoint (proves network integration works)

**Git:**
- [ ] .gitignore excludes .env, .env.local, __pycache__, venv/, xcuserdata/, DerivedData/, Config.plist
- [ ] .env.example exists in backend/ with safe dummy values (commit this, not .env.local)

---

## User Blockers (Complete Before Implementation)

**Setup Complete ✅:**
- [x] Supabase account with Project URL + keys
- [x] Railway Redis with PUBLIC_URL
- [x] NSW API key registered

**Pending Setup:**
- [ ] Install Redis CLI: `brew install redis` (for validation commands)
- [ ] Create backend/.env.local with actual credentials
- [ ] Create SydneyTransit/Config.plist with actual values

**Template Files (Agent will create):**
- backend/.env.example (safe template for .env.local)
- SydneyTransit/Config-Example.plist (safe template for Config.plist)

---

## Research Notes

**iOS Research Completed:**
- **SwiftUI @Observable vs ObservableObject (iOS 16 compatibility):** `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`
  - Key finding: iOS 16 minimum requires ObservableObject with @Published/@StateObject
  - Critical constraint: Cannot use @Observable macro (iOS 17+ only)

**On-Demand Research (During Implementation):**
- Railway Redis PUBLIC_URL format validation (agent will test connection)
- Supabase RLS policy syntax (deferred to Phase 3)
- NSW API rate limit headers (deferred to Phase 2)

**Confidence Check:**
If agent <80% confident on any pattern during implementation, agent MUST research before proceeding.

---

## Exploration Report

Attached: `.phase-logs/phase-0/exploration-report.json`

**Key Stats:**
- 11 checkpoints (granular, independently verifiable)
- 5 critical patterns extracted from DEVELOPMENT_STANDARDS
- 12 acceptance criteria (concrete validation commands)
- 8 user blockers identified (3 complete, 5 pending)

---

**Plan Created:** 2025-11-13
**Estimated Duration:** 1-2 weeks
