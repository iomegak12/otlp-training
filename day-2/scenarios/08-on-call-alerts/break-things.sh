#!/usr/bin/env bash
# Scenario 8 trigger: three things go wrong at once.
#   1. a market-data server dies                  -> InstanceDown
#   2. the end-of-day job fails every run          -> EodReconciliationFailed (then ...Stale)
#   3. 30% of trade-api requests fail with 5xx     -> ServiceHighErrorRate
set -euo pipefail
cd "$(dirname "$0")/../.."
docker compose stop market-data-2
perl -pi -e "s/^EOD_FAILURE_MODE=.*/EOD_FAILURE_MODE=always/" .env
docker compose up -d eod-reconciliation
curl -s -X POST "http://localhost:8080/admin/chaos?errorRate=0.3"; echo
echo "Alerts: http://localhost:9090/alerts   Alertmanager: http://localhost:9093   Inbox: http://localhost:8025"
