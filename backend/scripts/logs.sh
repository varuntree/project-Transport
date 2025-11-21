#!/bin/bash

# Tail logs for backend services (default VAR_DIR=var)
# Usage:
#   ./scripts/logs.sh              - tail all logs
#   ./scripts/logs.sh fastapi      - tail FastAPI only
#   ./scripts/logs.sh critical     - tail critical worker only
#   ./scripts/logs.sh service      - tail service worker only
#   ./scripts/logs.sh beat         - tail beat scheduler only

cd "$(dirname "$0")/.."

VAR_DIR=${VAR_DIR:-var}
LOG_DIR="$VAR_DIR/log"

if [ ! -d "$LOG_DIR" ]; then
    echo "No logs directory found. Start services first."
    exit 1
fi

# Map service names to log files
declare -A LOG_FILES=(
    ["fastapi"]="$LOG_DIR/fastapi.log"
    ["critical"]="$LOG_DIR/worker_critical.log"
    ["service"]="$LOG_DIR/worker_service.log"
    ["beat"]="$LOG_DIR/beat.log"
)

# If specific service requested
if [ $# -eq 1 ]; then
    SERVICE=$1
    if [ -z "${LOG_FILES[$SERVICE]}" ]; then
        echo "Unknown service: $SERVICE"
        echo ""
        echo "Available services:"
        echo "  - fastapi"
        echo "  - critical"
        echo "  - service"
        echo "  - beat"
        exit 1
    fi

    LOG_FILE="${LOG_FILES[$SERVICE]}"
    if [ ! -f "$LOG_FILE" ]; then
        echo "Log file not found: $LOG_FILE"
        echo "Service may not be running."
        exit 1
    fi

    echo "Tailing $SERVICE logs ($LOG_FILE)..."
    echo "Press Ctrl+C to stop"
    echo ""
    tail -f "$LOG_FILE"
    exit 0
fi

# Tail all logs
ALL_LOGS=""
for service in fastapi critical service beat; do
    log_file="${LOG_FILES[$service]}"
    if [ -f "$log_file" ]; then
        ALL_LOGS="$ALL_LOGS $log_file"
    fi
done

if [ -z "$ALL_LOGS" ]; then
    echo "No log files found. Start services first."
    exit 1
fi

echo "Tailing all logs..."
echo "Press Ctrl+C to stop"
echo ""
tail -f $ALL_LOGS
