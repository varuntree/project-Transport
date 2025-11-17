#!/bin/bash
cd "$(dirname "$0")/.."
celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info
