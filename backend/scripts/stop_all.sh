#!/bin/bash
# Stop all backend services using saved PIDs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.service_pids"

if [ ! -f "$PID_FILE" ]; then
    echo "No PID file found. Services may not be running or were started manually."
    echo "Attempting to find and kill processes by name..."
    
    # Fallback: kill by process name
    pkill -f "uvicorn app.main:app" 2>/dev/null
    pkill -f "celery.*celery_app worker" 2>/dev/null
    pkill -f "celery.*celery_app beat" 2>/dev/null
    
    echo "Done. Check if processes are still running with: ps aux | grep -E 'uvicorn|celery'"
    exit 0
fi

echo "Stopping all backend services..."
echo ""

# Read PIDs and kill each process
KILLED_COUNT=0
while IFS= read -r pid; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "Stopping process $pid..."
        kill "$pid" 2>/dev/null
        KILLED_COUNT=$((KILLED_COUNT + 1))
    fi
done < "$PID_FILE"

# Wait a moment for graceful shutdown
sleep 2

# Force kill any remaining processes
while IFS= read -r pid; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "Force killing process $pid..."
        kill -9 "$pid" 2>/dev/null
    fi
done < "$PID_FILE"

# Clean up PID file
rm -f "$PID_FILE"

echo ""
if [ $KILLED_COUNT -gt 0 ]; then
    echo "Stopped $KILLED_COUNT service(s)."
else
    echo "No running services found."
fi

# Also clean up any orphaned processes by name (safety net)
echo "Cleaning up any remaining processes..."
pkill -f "uvicorn app.main:app" 2>/dev/null
pkill -f "celery.*celery_app worker" 2>/dev/null
pkill -f "celery.*celery_app beat" 2>/dev/null

echo "Done!"

