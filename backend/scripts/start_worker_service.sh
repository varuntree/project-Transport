#!/bin/bash
cd "$(dirname "$0")/.."
celery -A app.tasks.celery_app worker -Q normal,batch -c 2 --autoscale=3,1 --loglevel=info
