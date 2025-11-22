#!/bin/bash

# Start all backend services (FastAPI + Celery workers + Beat)
# Logs: backend/var/log/*.log (override with VAR_DIR)
# PIDs: backend/var/pids/*.pid (override with VAR_DIR)
# Stop: ./scripts/stop_all.sh

set -e

# Change to backend directory
cd "$(dirname "$0")/.."

# Runtime directories (override with VAR_DIR env)
VAR_DIR=${VAR_DIR:-var}
PID_DIR="$VAR_DIR/pids"
LOG_DIR="$VAR_DIR/log"
CELERYBEAT_DIR="$VAR_DIR/celerybeat"
mkdir -p "$PID_DIR" "$LOG_DIR" "$CELERYBEAT_DIR"
SCHEDULE_FILE="$CELERYBEAT_DIR/celerybeat-schedule"

# Activate virtual environment if exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Function to check if service is already running
check_running() {
    local service_name=$1
    local pid_file="$PID_DIR/${service_name}.pid"

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$service_name already running (PID: $pid)"
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    return 1
}

# Check if any services are already running
ALREADY_RUNNING=false
for service in fastapi worker_critical worker_service beat; do
    if check_running "$service"; then
        ALREADY_RUNNING=true
    fi
done

if [ "$ALREADY_RUNNING" = true ]; then
    echo ""
    echo "Stop existing services first with: ./scripts/stop_all.sh"
    exit 1
fi

echo "Starting all backend services..."
echo ""

# Check if Redis is running
echo "[0/4] Checking Redis..."
if ! redis-cli ping >/dev/null 2>&1; then
    echo "  ⚠ Redis not running - attempting to start..."
    if command -v brew >/dev/null 2>&1; then
        brew services start redis >/dev/null 2>&1
        sleep 2
        if redis-cli ping >/dev/null 2>&1; then
            echo "  ✓ Redis started successfully"
        else
            echo "  ✗ Failed to start Redis"
            echo ""
            echo "ERROR: Redis is required for GTFS-RT caching (Phase 2.2)"
            echo "Install: brew install redis"
            echo "Start:   brew services start redis"
            exit 1
        fi
    else
        echo "  ✗ Redis not running and Homebrew not found"
        echo ""
        echo "ERROR: Redis is required for GTFS-RT caching (Phase 2.2)"
        echo "Install: brew install redis"
        echo "Start:   brew services start redis"
        exit 1
    fi
else
    echo "  ✓ Redis already running"
fi

echo ""

# Start FastAPI
echo "[1/5] Starting FastAPI..."
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /dev/null 2>&1 &
echo $! > "$PID_DIR/fastapi.pid"
echo "  ✓ FastAPI started (PID: $(cat $PID_DIR/fastapi.pid))"
echo "    - API: http://localhost:8000"
echo "    - Logs: $LOG_DIR/fastapi.log"

sleep 1

# Start Celery Worker - Critical Queue
echo ""
echo "[2/5] Starting Celery Worker (Critical Queue)..."
nohup celery -A app.tasks.celery_app worker -Q critical --pool=solo --loglevel=info > /dev/null 2>&1 &
echo $! > "$PID_DIR/worker_critical.pid"
echo "  ✓ Critical worker started (PID: $(cat $PID_DIR/worker_critical.pid))"
echo "    - Queue: critical (GTFS-RT polling every 30s)"
echo "    - Logs: $LOG_DIR/worker_critical.log"

sleep 1

# Start Celery Worker - Normal + Batch Queues
echo ""
echo "[3/5] Starting Celery Worker (Normal + Batch Queues)..."
nohup celery -A app.tasks.celery_app worker -Q normal,batch --pool=solo --loglevel=info > /dev/null 2>&1 &
echo $! > "$PID_DIR/worker_service.pid"
echo "  ✓ Service worker started (PID: $(cat $PID_DIR/worker_service.pid))"
echo "    - Queues: normal (alerts, APNs), batch (GTFS sync)"
echo "    - Logs: $LOG_DIR/worker_service.log"

sleep 1

# Start Celery Beat
echo ""
echo "[4/5] Starting Celery Beat (Scheduler)..."
nohup celery -A app.tasks.celery_app beat --loglevel=info --schedule "$SCHEDULE_FILE" > /dev/null 2>&1 &
echo $! > "$PID_DIR/beat.pid"
echo "  ✓ Beat scheduler started (PID: $(cat $PID_DIR/beat.pid))"
echo "    - Schedules: RT poll (30s), GTFS sync (03:10), alerts (2-5min)"
echo "    - Logs: $LOG_DIR/beat.log"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All services started successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Commands:"
echo "  - Stop all:     ./scripts/stop_all.sh"
echo "  - View logs:    ./scripts/logs.sh"
echo "  - Health check: curl http://localhost:8000/health"
echo ""
echo "Log files:"
echo "  - FastAPI:        $LOG_DIR/fastapi.log"
echo "  - Worker (RT):    $LOG_DIR/worker_critical.log"
echo "  - Worker (Svc):   $LOG_DIR/worker_service.log"
echo "  - Beat:           $LOG_DIR/beat.log"
echo ""
