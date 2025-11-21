#!/bin/bash

# Start FastAPI only (for quick API testing)
# Logs: backend/var/log/fastapi.log (override with VAR_DIR)
# PID: backend/var/pids/fastapi.pid (override with VAR_DIR)
# Stop: ./scripts/stop_all.sh

set -e

# Change to backend directory
cd "$(dirname "$0")/.."

# Runtime directories (override with VAR_DIR env)
VAR_DIR=${VAR_DIR:-var}
PID_DIR="$VAR_DIR/pids"
LOG_DIR="$VAR_DIR/log"

# Create directories
mkdir -p "$PID_DIR" "$LOG_DIR"

# Activate virtual environment if exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Check if FastAPI is already running
PID_FILE="$PID_DIR/fastapi.pid"
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
echo "  - Logs: $LOG_DIR/fastapi.log"
echo "  - PID: $PID_FILE"
echo ""
echo "Stop with: ./scripts/stop_all.sh"
echo ""

# Start FastAPI in background
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /dev/null 2>&1 &
echo $! > "$PID_FILE"

echo "FastAPI started (PID: $(cat $PID_FILE))"
