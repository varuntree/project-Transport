#!/bin/bash
# Start all backend services and save PIDs for easy shutdown

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$SCRIPT_DIR/.service_pids"

# Change to backend directory
cd "$BACKEND_DIR"

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "Warning: venv not found. Make sure virtual environment is activated."
fi

# Clear any existing PID file
> "$PID_FILE"

echo "Starting all backend services..."
echo "PID file: $PID_FILE"
echo ""

# Start FastAPI server
echo "Starting FastAPI server..."
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 > /tmp/sydney_transit_fastapi.log 2>&1 &
FASTAPI_PID=$!
echo "FastAPI PID: $FASTAPI_PID"
echo "$FASTAPI_PID" >> "$PID_FILE"
sleep 2

# Start Celery Worker (Critical Queue)
echo "Starting Celery Worker (Critical)..."
celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info > /tmp/sydney_transit_celery_critical.log 2>&1 &
CELERY_CRITICAL_PID=$!
echo "Celery Critical PID: $CELERY_CRITICAL_PID"
echo "$CELERY_CRITICAL_PID" >> "$PID_FILE"
sleep 1

# Start Celery Worker (Normal + Batch)
echo "Starting Celery Worker (Normal + Batch)..."
celery -A app.tasks.celery_app worker -Q normal,batch -c 2 --autoscale=3,1 --loglevel=info > /tmp/sydney_transit_celery_service.log 2>&1 &
CELERY_SERVICE_PID=$!
echo "Celery Service PID: $CELERY_SERVICE_PID"
echo "$CELERY_SERVICE_PID" >> "$PID_FILE"
sleep 1

# Start Celery Beat
echo "Starting Celery Beat..."
celery -A app.tasks.celery_app beat --loglevel=info > /tmp/sydney_transit_celery_beat.log 2>&1 &
CELERY_BEAT_PID=$!
echo "Celery Beat PID: $CELERY_BEAT_PID"
echo "$CELERY_BEAT_PID" >> "$PID_FILE"

echo ""
echo "=========================================="
echo "All services started!"
echo "=========================================="
echo "FastAPI Server:     http://localhost:8000"
echo "FastAPI Logs:       tail -f /tmp/sydney_transit_fastapi.log"
echo "Celery Critical:    tail -f /tmp/sydney_transit_celery_critical.log"
echo "Celery Service:     tail -f /tmp/sydney_transit_celery_service.log"
echo "Celery Beat:        tail -f /tmp/sydney_transit_celery_beat.log"
echo ""
echo "To stop all services, run:"
echo "  bash scripts/stop_all.sh"
echo "=========================================="

