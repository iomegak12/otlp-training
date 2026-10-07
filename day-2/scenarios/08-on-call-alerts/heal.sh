#!/usr/bin/env bash
# Scenario 8: undo break-things.sh (resolved notifications arrive by e-mail).
set -euo pipefail
cd "$(dirname "$0")/../.."
docker compose start market-data-2
perl -pi -e "s/^EOD_FAILURE_MODE=.*/EOD_FAILURE_MODE=random/" .env
docker compose up -d eod-reconciliation
curl -s -X POST "http://localhost:8080/admin/chaos?latencyMs=0&errorRate=0"; echo
