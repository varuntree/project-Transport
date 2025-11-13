# Checkpoint 1: Backend Project Structure

## Goal
Create FastAPI project directory layout matching DEVELOPMENT_STANDARDS.md Section 1 with pinned dependencies and safe environment template.

## Approach

### Backend Implementation
Create complete backend/ directory structure:
```
backend/
├── app/
│   ├── __init__.py
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       └── __init__.py
│   ├── db/
│   │   └── __init__.py
│   ├── models/
│   │   └── __init__.py
│   ├── services/
│   │   └── __init__.py
│   ├── tasks/
│   │   └── __init__.py
│   └── utils/
│       └── __init__.py
├── requirements.txt
├── .env.example
└── .gitignore
```

**requirements.txt (pinned versions):**
- fastapi==0.104.1
- uvicorn[standard]==0.24.0
- celery==5.3.4
- redis==5.0.1
- supabase==2.0.3
- structlog==23.2.0
- pydantic==2.5.0
- pydantic-settings==2.1.0
- python-dotenv==1.0.0

**.env.example template:**
```bash
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Redis
REDIS_URL=redis://default:password@host.railway.app:PORT

# NSW API
NSW_API_KEY=your_nsw_api_key_here

# Server
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
LOG_LEVEL=INFO
```

**.gitignore:**
```
# Environment
.env
.env.local
.env.*.local

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/
.venv

# IDEs
.vscode/
.idea/
*.swp
*.swo

# Testing
.pytest_cache/
.coverage
htmlcov/
```

### iOS Implementation
None

## Design Constraints
- Follow DEVELOPMENT_STANDARDS.md:L36-82 directory structure exactly
- Use pinned versions (no `latest` or `^` ranges)
- .env.example must have ALL vars config.py will require, but with safe dummy values
- All __init__.py files should be empty (packages only)

## Risks
- Missing __init__.py → Python won't recognize directories as packages
  - Mitigation: Create __init__.py in all directories under app/

## Validation
```bash
ls -R backend/
# Expected: app/api/v1, app/db, app/utils, app/tasks, app/models, app/services, requirements.txt, .env.example, .gitignore

cat backend/requirements.txt | grep fastapi
# Expected: fastapi==0.104.1
```

## References for Subagent
- Directory structure: DEVELOPMENT_STANDARDS.md:L36-82
- Dependencies: BACKEND_SPECIFICATION.md:Section 1

## Estimated Complexity
**simple** - Basic directory creation, no logic
