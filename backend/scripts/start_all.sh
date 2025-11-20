#!/bin/bash

# Start all backend services (FastAPI + Celery workers + Beat)
# Logs: backend/logs/*.log (separate file per service)
# PIDs: backend/scripts/.service_pids/*.pid
# Stop: ./scripts/stop_all.sh

set -e

# Change to backend directory
cd "$(dirname "$0")/.."

# Create directories
mkdir -p scripts/.service_pids
mkdir -p logs

# Activate virtual environment if exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Function to check if service is already running
check_running() {
    local service_name=$1
    local pid_file="scripts/.service_pids/${service_name}.pid"

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

# Start FastAPI
echo "[1/4] Starting FastAPI..."
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /dev/null 2>&1 &
echo $! > scripts/.service_pids/fastapi.pid
echo "  ✓ FastAPI started (PID: $(cat scripts/.service_pids/fastapi.pid))"
echo "    - API: http://localhost:8000"
echo "    - Logs: logs/fastapi.log"

sleep 1

# Start Celery Worker - Critical Queue
echo ""
echo "[2/4] Starting Celery Worker (Critical Queue)..."
nohup celery -A app.tasks.celery_app worker -Q critical --pool=solo --loglevel=info > /dev/null 2>&1 &
echo $! > scripts/.service_pids/worker_critical.pid
echo "  ✓ Critical worker started (PID: $(cat scripts/.service_pids/worker_critical.pid))"
echo "    - Queue: critical (GTFS-RT polling every 30s)"
echo "    - Logs: logs/worker_critical.log"

sleep 1

# Start Celery Worker - Normal + Batch Queues
echo ""
echo "[3/4] Starting Celery Worker (Normal + Batch Queues)..."
nohup celery -A app.tasks.celery_app worker -Q normal,batch --pool=solo --loglevel=info > /dev/null 2>&1 &
echo $! > scripts/.service_pids/worker_service.pid
echo "  ✓ Service worker started (PID: $(cat scripts/.service_pids/worker_service.pid))"
echo "    - Queues: normal (alerts, APNs), batch (GTFS sync)"
echo "    - Logs: logs/worker_service.log"

sleep 1

# Start Celery Beat
echo ""
echo "[4/4] Starting Celery Beat (Scheduler)..."
nohup celery -A app.tasks.celery_app beat --loglevel=info > /dev/null 2>&1 &
echo $! > scripts/.service_pids/beat.pid
echo "  ✓ Beat scheduler started (PID: $(cat scripts/.service_pids/beat.pid))"
echo "    - Schedules: RT poll (30s), GTFS sync (03:10), alerts (2-5min)"
echo "    - Logs: logs/beat.log"

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
echo "  - FastAPI:        logs/fastapi.log"
echo "  - Worker (RT):    logs/worker_critical.log"
echo "  - Worker (Svc):   logs/worker_service.log"
echo "  - Beat:           logs/beat.log"
echo ""
