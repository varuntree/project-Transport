#!/bin/bash
cd "$(dirname "$0")/.."
celery -A app.tasks.celery_app beat --loglevel=info
