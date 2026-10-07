#!/usr/bin/env bash
# Scenario 5 trigger: a 2-minute Loki "maintenance window".
#   loki-outage.sh            stop Loki, wait 120 s, start it again
#   loki-outage.sh 60         the same with a 60-second outage
set -euo pipefail
cd "$(dirname "$0")/../.."
seconds="${1:-120}"
docker compose stop loki
echo "Loki stopped at $(date +%H:%M:%S). Waiting ${seconds}s ..."
sleep "$seconds"
docker compose start loki
echo "Loki started again at $(date +%H:%M:%S)."
