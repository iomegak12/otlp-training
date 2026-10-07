#!/usr/bin/env bash
# Scenario 6 and 8: change how often the end-of-day job fails, then restart it.
#   failure-mode.sh always | random | never
set -euo pipefail
cd "$(dirname "$0")/../.."
mode="${1:?Usage: failure-mode.sh always|random|never}"
perl -pi -e "s/^EOD_FAILURE_MODE=.*/EOD_FAILURE_MODE=$mode/" .env
docker compose up -d eod-reconciliation
docker compose logs --tail 3 eod-reconciliation
