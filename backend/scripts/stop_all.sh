#!/bin/bash

# Stop all backend services gracefully
# Reads PIDs from scripts/.service_pids/*.pid
# Sends SIGTERM (graceful), waits 5s, then SIGKILL if needed

cd "$(dirname "$0")/.."

PID_DIR="scripts/.service_pids"

if [ ! -d "$PID_DIR" ] || [ -z "$(ls -A $PID_DIR 2>/dev/null)" ]; then
    echo "No running services found"
    exit 0
fi

echo "Stopping backend services..."
echo ""

# Function to stop a service
stop_service() {
    local pid_file=$1
    local service_name=$(basename "$pid_file" .pid)

    if [ ! -f "$pid_file" ]; then
        return
    fi

    local pid=$(cat "$pid_file")

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "  $service_name (PID: $pid) - not running"
        rm -f "$pid_file"
        return
    fi

    # Send SIGTERM for graceful shutdown
    echo "  $service_name (PID: $pid) - stopping..."
    kill -TERM "$pid" 2>/dev/null || true

    # Wait up to 5 seconds for graceful shutdown
    local count=0
    while kill -0 "$pid" 2>/dev/null && [ $count -lt 50 ]; do
        sleep 0.1
        count=$((count + 1))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "    ⚠ Process didn't stop gracefully, forcing..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 0.5
    fi

    # Verify stopped
    if kill -0 "$pid" 2>/dev/null; then
        echo "    ✗ Failed to stop $service_name"
    else
        echo "    ✓ Stopped"
    fi

    rm -f "$pid_file"
}

# Stop services in reverse order (Beat, Workers, FastAPI)
# This ensures scheduled tasks don't queue after workers stop
for service in beat worker_service worker_critical fastapi; do
    pid_file="$PID_DIR/${service}.pid"
    if [ -f "$pid_file" ]; then
        stop_service "$pid_file"
    fi
done

echo ""
echo "✓ All services stopped"
