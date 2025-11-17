#!/bin/bash

# Start FastAPI only (for quick API testing)
# Logs: backend/logs/fastapi.log
# PID: backend/scripts/.service_pids/fastapi.pid
# Stop: ./scripts/stop_all.sh

set -e

# Change to backend directory
cd "$(dirname "$0")/.."

# Create PID directory
mkdir -p scripts/.service_pids

# Activate virtual environment if exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Check if FastAPI is already running
PID_FILE="scripts/.service_pids/fastapi.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "FastAPI already running (PID: $OLD_PID)"
        echo "Stop it first with: ./scripts/stop_all.sh"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

echo "Starting FastAPI server..."
echo "  - API: http://localhost:8000"
echo "  - Logs: logs/fastapi.log"
echo "  - PID: $PID_FILE"
echo ""
echo "Stop with: ./scripts/stop_all.sh"
echo ""

# Start FastAPI in background
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /dev/null 2>&1 &
echo $! > "$PID_FILE"

echo "FastAPI started (PID: $(cat $PID_FILE))"
