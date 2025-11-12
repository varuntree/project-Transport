# Phase 0: Foundation
**Duration:** 1-2 weeks
**Timeline:** Week 1-2
**Goal:** Local dev environment, project scaffolding, hello-world endpoints

---

## Overview

This phase establishes the development foundation for both backend and iOS. By the end, you'll have:
- FastAPI backend running locally (`http://localhost:8000`)
- iOS app running in simulator
- Supabase connected (empty DB)
- Redis connected (Railway managed)
- Git repo initialized with proper structure

**No external integrations yet** - just hello-world to verify tooling works.

---

## Prerequisites

### Required Accounts (User Setup)
Complete these **before** starting implementation:

1. **Supabase Account**
   - Sign up: https://supabase.com/
   - Create new project: `sydney-transit-dev`
   - Region: Sydney (Australia Southeast)
   - Plan: Free tier (500MB DB, 50K MAU)
   - Note down:
     - Project URL: `https://xxxxx.supabase.co`
     - `anon` key (public key for client)
     - `service_role` key (backend only, keep secret)

2. **Railway Account**
   - Sign up: https://railway.app/
   - Create new project: `sydney-transit-backend`
   - Add Redis service (Provision → Redis → Deploy)
   - Plan: Free tier ($5 credit/month)
   - Note down:
     - Redis connection URL: `redis://default:password@redis.railway.app:6379`

3. **NSW Transport API Key**
   - Register: https://opendata.transport.nsw.gov.au/
   - Create application: "Sydney Transit App - Dev"
   - Request API access (approved within 24 hours)
   - Note down:
     - API key: `apikey_xxxxxxxxxxxxx`
   - Test API key: `curl -H "Authorization: apikey YOUR_KEY" https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains/complete`

4. **Apple Developer Account** (Optional for Phase 0, required for Phase 3)
   - $99/year (can defer until Phase 3 for Apple Sign-In)
   - For now: Use Xcode simulator (no paid account needed)

5. **Development Tools**
   - macOS: 13.0+ (required for Xcode 15)
   - Xcode: 15.0+ (download from App Store)
   - Python: 3.11+ (install via Homebrew: `brew install python@3.11`)
   - Git: 2.30+ (pre-installed on macOS)
   - Redis CLI: `brew install redis` (for local testing)

---

## User Instructions (Complete First)

### Step 1: Set Up Supabase Project

1. Log in to https://supabase.com/dashboard
2. Click "New Project"
3. Configure:
   - Name: `sydney-transit-dev`
   - Database Password: Generate strong password, save to password manager
   - Region: Sydney (Australia Southeast)
   - Pricing Plan: Free
4. Wait for project to provision (~2 minutes)
5. Navigate to Settings → API
6. Copy the following (you'll provide these to AI agent):
   - Project URL
   - `anon` public key
   - `service_role` secret key (NEVER commit to git)
7. Enable PostGIS extension:
   - Go to Database → Extensions
   - Search "postgis"
   - Click "Enable" (required for geospatial queries in Phase 1)

### Step 2: Set Up Railway Redis

1. Log in to https://railway.app/
2. Click "New Project"
3. Select "Provision Redis"
4. Name: `sydney-transit-redis`
5. Click "Deploy"
6. Once deployed, click Redis service → Connect
7. Copy connection URL: `redis://default:PASSWORD@HOSTNAME:PORT`
8. Test connection locally:
   ```bash
   redis-cli -u redis://default:PASSWORD@HOSTNAME:PORT
   # Should connect, type: PING
   # Expected: PONG
   ```

### Step 3: Get NSW Transport API Key

1. Go to https://opendata.transport.nsw.gov.au/
2. Register account (or log in)
3. Dashboard → Create Application
4. Fill form:
   - App Name: Sydney Transit App - Dev
   - Description: iOS transit app for Sydney
   - Estimated API calls: 50K/month
5. Submit (approval within 24 hours, check email)
6. Once approved, copy API key from dashboard
7. Test API key:
   ```bash
   curl -H "Authorization: apikey YOUR_API_KEY" \
     https://api.transport.nsw.gov.au/v1/gtfs/alerts/buses
   ```
   - Should return JSON (GTFS-RT alerts feed)
   - If 401: Invalid key
   - If 403: Rate limit (wait 1 second, retry)

### Step 4: Create Environment Variables File

Create `.env` file in project root (AI agent will reference this):

```bash
# .env (NEVER commit to git)

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Redis
REDIS_URL=redis://default:password@redis.railway.app:6379

# NSW Transport API
NSW_API_KEY=apikey_xxxxxxxxxxxxx

# Celery (same as Redis)
CELERY_BROKER_URL=redis://default:password@redis.railway.app:6379

# Environment
ENVIRONMENT=development
LOG_LEVEL=DEBUG
```

**Security:** Create `.env.example` (without real values) and commit that instead.

---

## Implementation Checklist (AI Agent Tasks)

### Backend Setup

**1. Project Structure**
- [ ] Create directory structure (see DEVELOPMENT_STANDARDS.md Section 1):
  ```
  backend/
  ├── app/
  │   ├── __init__.py
  │   ├── main.py
  │   ├── config.py
  │   ├── api/v1/__init__.py
  │   ├── db/supabase_client.py
  │   ├── db/redis_client.py
  │   └── utils/logging.py
  ├── .env (user provides)
  ├── .env.example (commit this)
  ├── .gitignore
  ├── requirements.txt
  └── README.md
  ```

**2. Dependencies (requirements.txt)**
```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
celery[redis]==5.3.4
redis==5.0.1
supabase==2.0.3
structlog==23.2.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
```

**3. Configuration (app/config.py)**
- [ ] Use Pydantic Settings to load `.env` (see DEVELOPMENT_STANDARDS.md Section 7)
- [ ] Validate required env vars (SUPABASE_URL, REDIS_URL, NSW_API_KEY)
- [ ] Provide clear error if any var missing

**4. Supabase Client (app/db/supabase_client.py)**
- [ ] Singleton pattern (see DEVELOPMENT_STANDARDS.md Section 2)
- [ ] Use `SUPABASE_SERVICE_KEY` (not anon key)
- [ ] FastAPI Depends() integration
- [ ] Connection test function (`test_connection()`)

**5. Redis Client (app/db/redis_client.py)**
- [ ] Singleton async Redis client (see DEVELOPMENT_STANDARDS.md Section 2)
- [ ] Connection test function (`test_connection()`)

**6. Structured Logging (app/utils/logging.py)**
- [ ] Configure structlog (JSON output, see DEVELOPMENT_STANDARDS.md Section 4)
- [ ] Log levels: DEBUG in dev, INFO in prod
- [ ] Test with sample log events

**7. FastAPI App (app/main.py)**
- [ ] Create FastAPI instance
- [ ] Enable CORS (allow all origins in dev, restrict in prod)
- [ ] Add startup event: Test Supabase + Redis connections
- [ ] Add health check endpoint: `GET /health`
  - Returns: `{"status": "healthy", "services": {"db": "connected", "cache": "connected"}}`
  - Test DB connection (simple query: `SELECT 1`)
  - Test Redis connection (PING)
- [ ] Add root endpoint: `GET /` → `{"message": "Sydney Transit API", "version": "0.1.0"}`

**8. .gitignore**
```
.env
__pycache__/
*.pyc
.venv/
venv/
.DS_Store
```

**9. README.md**
- [ ] Setup instructions (install deps, create .env, run server)
- [ ] cURL commands to test endpoints

---

### iOS Setup

**1. Project Structure**
- [ ] Create Xcode project: `SydneyTransit`
- [ ] Minimum iOS version: 16.0
- [ ] SwiftUI lifecycle
- [ ] Project structure (see DEVELOPMENT_STANDARDS.md Section 1):
  ```
  SydneyTransit/
  ├── SydneyTransitApp.swift
  ├── Config.plist
  ├── Core/
  │   ├── Utilities/Logger.swift
  │   └── Utilities/Constants.swift
  ├── Features/
  │   └── Home/
  │       └── HomeView.swift
  └── Resources/
      └── Assets.xcassets
  ```

**2. Dependencies (Swift Package Manager)**
- [ ] Add package: Supabase Swift (`https://github.com/supabase/supabase-swift.git`, version 2.0.0+)
- [ ] Add package: swift-log (`https://github.com/apple/swift-log.git`, version 1.5.3+)

**3. Configuration (Config.plist)**
- [ ] Create Config.plist in project root
- [ ] Add keys:
  ```xml
  <dict>
    <key>API_BASE_URL</key>
    <string>http://localhost:8000/api/v1</string>

    <key>SUPABASE_URL</key>
    <string>https://xxxxx.supabase.co</string>

    <key>SUPABASE_ANON_KEY</key>
    <string>eyJhbGci...</string>

    <key>LOG_LEVEL</key>
    <string>debug</string>
  </dict>
  ```
- [ ] User will provide Supabase values

**4. Constants (Core/Utilities/Constants.swift)**
- [ ] Read Config.plist values (see DEVELOPMENT_STANDARDS.md Section 7)
- [ ] Expose as static properties: `Config.apiBaseURL`, `Config.supabaseURL`

**5. Logger (Core/Utilities/Logger.swift)**
- [ ] Configure swift-log (see DEVELOPMENT_STANDARDS.md Section 4)
- [ ] Usage: `Logger.app.info("App launched")`

**6. Home Screen (Features/Home/HomeView.swift)**
- [ ] Simple SwiftUI view:
  ```swift
  struct HomeView: View {
      var body: some View {
          NavigationStack {
              VStack {
                  Text("Sydney Transit")
                      .font(.largeTitle)
                  Text("Phase 0: Foundation")
                      .foregroundColor(.secondary)
              }
              .navigationTitle("Home")
          }
      }
  }
  ```

**7. App Entry Point (SydneyTransitApp.swift)**
- [ ] Set HomeView as root view
- [ ] Initialize logger on app launch
- [ ] Log app startup event

**8. .gitignore**
```
.DS_Store
xcuserdata/
*.xcworkspace/xcshareddata/
DerivedData/
Config.plist
```

**9. README.md**
- [ ] Setup instructions (open in Xcode, add Config.plist, run)

---

## Acceptance Criteria (Manual Testing)

### Backend Tests

**1. Server Starts**
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
- [ ] Server starts without errors
- [ ] Console shows: "Application startup complete"
- [ ] Logs show: Supabase connected, Redis connected

**2. Health Check Endpoint**
```bash
curl http://localhost:8000/health
```
Expected response:
```json
{
  "status": "healthy",
  "services": {
    "db": "connected",
    "cache": "connected"
  }
}
```
- [ ] Returns 200 status code
- [ ] JSON matches expected structure
- [ ] Both services show "connected"

**3. Root Endpoint**
```bash
curl http://localhost:8000/
```
Expected response:
```json
{
  "message": "Sydney Transit API",
  "version": "0.1.0"
}
```

**4. Logs Are Structured**
- [ ] Console output is JSON format
- [ ] Each log entry has: `timestamp`, `level`, `event`
- [ ] Startup logs include: `server_started`, `db_connected`, `redis_connected`

**5. Environment Variables Loaded**
```bash
python -c "from app.config import settings; print(settings.SUPABASE_URL)"
```
- [ ] Prints Supabase URL (not None)
- [ ] No error about missing env vars

---

### iOS Tests

**1. App Builds and Launches**
- [ ] Open `SydneyTransit.xcodeproj` in Xcode
- [ ] Select iPhone 15 Pro simulator
- [ ] Press Cmd+R (Run)
- [ ] App launches without crashes
- [ ] Home screen shows "Sydney Transit" title

**2. Logger Works**
- [ ] Check Xcode console output
- [ ] Should see: "App launched" log entry
- [ ] Log level is "debug"

**3. Config Values Loaded**
- [ ] Add breakpoint in `Constants.swift`
- [ ] Verify `Config.apiBaseURL` is `http://localhost:8000/api/v1`
- [ ] Verify `Config.supabaseURL` matches your Supabase project URL

**4. No Build Warnings**
- [ ] No SwiftUI deprecation warnings
- [ ] No package resolution errors
- [ ] Build succeeds with 0 warnings

---

### Integration Tests

**1. iOS Can Reach Backend**
(This requires adding a simple network call, do this last)

Add to HomeView:
```swift
@State private var apiStatus = "Not checked"

.onAppear {
    Task {
        do {
            let url = URL(string: "\(Config.apiBaseURL)/")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode([String: String].self, from: data)
            apiStatus = json["message"] ?? "Unknown"
        } catch {
            apiStatus = "Error: \(error.localizedDescription)"
        }
    }
}
```

- [ ] Launch iOS app (simulator)
- [ ] Backend must be running (`uvicorn app.main:app --reload`)
- [ ] Home screen shows: "Sydney Transit API" (fetched from backend)
- [ ] If error: Check firewall, verify backend URL in Config.plist

---

## Troubleshooting

### Backend Issues

**Problem:** `ModuleNotFoundError: No module named 'app'`
- **Solution:** Run from project root: `cd backend && uvicorn app.main:app`

**Problem:** `ValueError: SUPABASE_URL is required`
- **Solution:** Create `.env` file in `backend/` directory, not project root

**Problem:** Supabase connection fails
- **Solution:**
  - Check Supabase project is active (not paused)
  - Verify `SUPABASE_SERVICE_KEY` (not anon key)
  - Test connection: `curl https://xxxxx.supabase.co/rest/v1/` (should return 404, not 401)

**Problem:** Redis connection fails
- **Solution:**
  - Verify Railway Redis is deployed (check dashboard)
  - Test connection: `redis-cli -u REDIS_URL` → `PING` → should return `PONG`
  - Check firewall (Railway should allow all IPs)

### iOS Issues

**Problem:** "No such module 'Supabase'"
- **Solution:** File → Packages → Resolve Package Versions

**Problem:** Config.plist not found
- **Solution:** Add to Xcode: Right-click project → Add Files → Config.plist → Ensure "Copy items if needed" is checked

**Problem:** iOS can't reach localhost backend
- **Solution:** Use `http://127.0.0.1:8000` instead of `http://localhost:8000` in Config.plist

**Problem:** Simulator shows blank screen
- **Solution:** Check console for SwiftUI errors, verify HomeView is set as root in SydneyTransitApp.swift

---

## Git Workflow

### Initialize Repository
```bash
cd /path/to/sydney-transit
git init
git checkout -b phase-0-foundation
```

### Commits
Make atomic commits as you work:
```bash
git add backend/
git commit -m "feat: setup FastAPI project structure"

git add backend/app/main.py
git commit -m "feat: add health check endpoint"

git add SydneyTransit/
git commit -m "feat: setup iOS project with SwiftUI"
```

### Phase Complete
```bash
git add .
git commit -m "feat: phase 0 foundation complete"
git tag phase-0-complete
git checkout main
git merge phase-0-foundation
```

---

## Deliverables Checklist

Before moving to Phase 1:

**Backend:**
- [ ] FastAPI server runs locally
- [ ] `/health` endpoint returns 200
- [ ] Supabase connected (can query DB)
- [ ] Redis connected (can PING)
- [ ] Structured logging works (JSON output)
- [ ] .env file created (not committed)
- [ ] README.md with setup instructions

**iOS:**
- [ ] App launches in simulator
- [ ] Home screen displays
- [ ] Logger configured
- [ ] Config.plist loaded
- [ ] Can fetch data from backend (integration test passes)
- [ ] README.md with setup instructions

**Git:**
- [ ] Repository initialized
- [ ] `.gitignore` configured
- [ ] All code committed to `phase-0-foundation` branch
- [ ] Tagged `phase-0-complete`

**Documentation:**
- [ ] `.env.example` created (safe to commit)
- [ ] Both READMEs updated with setup steps
- [ ] User setup instructions verified (all accounts created)

---

## Next Phase Preview

**Phase 1: Static Data + Basic UI**
- Download GTFS static dataset (227MB)
- Parse GTFS CSV files → Supabase tables
- Generate iOS SQLite database (15-20MB)
- Build iOS UI: Stops list, search, route details
- All offline (no real-time yet)

**Estimated Start:** After Phase 0 complete (~Week 3)

---

## Notes

**Why This Phase Matters:**
- Validates tooling setup (no surprises in later phases)
- Tests external service connectivity (Supabase, Redis, NSW API)
- Establishes project structure (all future code follows this pattern)
- Proves iOS ↔ Backend integration works

**Keep It Simple:**
- No databases queries yet (just connection tests)
- No Celery workers yet (just FastAPI)
- No iOS UI complexity (just hello-world)
- Goal: Green lights on all services, ready for Phase 1 complexity

---

**End of PHASE_0_FOUNDATION.md**
