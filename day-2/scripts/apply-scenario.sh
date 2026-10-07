#!/usr/bin/env bash
# Jump to the finished state of a scenario (use it if a live demo goes wrong).
#
#   scripts/apply-scenario.sh 4      # state after scenario 4 (1-9)
#
# Copies scenarios/0N-*/after/ over the lab folder (.env, collector/agent/config.yaml,
# infra/prometheus/prometheus.yml, infra/tempo/tempo.yaml) and restarts what changed.
set -euo pipefail
cd "$(dirname "$0")/.."

n="${1:-}"
dir=$(ls -d scenarios/0"${n}"-* 2>/dev/null | head -1 || true)
if [[ -z "$n" || -z "$dir" || "$n" == "0" ]]; then
  echo "Usage: scripts/apply-scenario.sh <1-9>"; exit 1
fi

echo "Applying $dir/after"
cp -R "$dir/after/." ./
docker compose up -d eod-reconciliation otel-agent   # recreated only if their .env values changed
docker compose restart otel-agent tempo   # reload their config files
curl -s -X POST http://localhost:9090/-/reload && echo "Prometheus configuration reloaded"
echo "Now at the end of scenario $n."
