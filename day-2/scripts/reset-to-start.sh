#!/usr/bin/env bash
# Put the whole lab back in the starting ("problem") state for all nine scenarios.
set -euo pipefail
cd "$(dirname "$0")/.."

cp -R scenarios/00-start/. ./
docker compose unpause tempo 2>/dev/null || true
docker compose up -d
docker compose restart otel-agent tempo
curl -s -X POST http://localhost:9090/-/reload && echo "Prometheus configuration reloaded"
curl -s -X POST "http://localhost:8080/admin/chaos?latencyMs=0&errorRate=0" > /dev/null && echo "trade-api chaos cleared"
docker compose run --rm fleet scale 3
echo "Lab reset to the starting state."
