#!/usr/bin/env bash
# Scenario 2 trigger: the market-open spike (about 2 minutes).
#
#   1. Pauses Tempo, so the agent cannot deliver traces and has to hold them in memory.
#   2. Floods the agent with traces for 90 seconds (telemetrygen).
#   3. Resumes Tempo as soon as the spike is over, so the agent can drain its queue and
#      telemetrygen can flush its last spans and exit.
#
# Tempo is always resumed, even if you press Ctrl+C.
#
# Watch in another terminal:   docker stats tradenova-day2-otel-agent-1
set -uo pipefail
cd "$(dirname "$0")/../.."

AGENT=tradenova-day2-otel-agent-1
SPIKE_SECONDS=90   # must match --duration of the telemetrygen service in docker-compose.yml

resume_tempo() { docker compose unpause tempo > /dev/null 2>&1 || true; }
trap resume_tempo EXIT INT TERM

restarts_before=$(docker inspect "$AGENT" --format '{{.RestartCount}}' 2>/dev/null || echo "?")
echo ">>> otel-agent restart count before the spike: $restarts_before"

docker compose pause tempo
echo ">>> $(date +%H:%M:%S) Tempo paused. Flooding the agent for ${SPIKE_SECONDS} seconds ..."

# Resume Tempo when the spike ends, without waiting for telemetrygen to exit.
(
  sleep $((SPIKE_SECONDS + 2))
  resume_tempo
  echo ">>> $(date +%H:%M:%S) Spike over: Tempo resumed. The agent now delivers its backlog."
) &
timer=$!

docker compose --profile spike run --rm telemetrygen || true

# telemetrygen has exited; make sure the timer is finished and Tempo is running.
kill "$timer" 2> /dev/null
wait "$timer" 2> /dev/null
resume_tempo

echo ">>> $(date +%H:%M:%S) Done."
docker inspect "$AGENT" --format ">>> otel-agent: status={{.State.Status}} OOMKilled={{.State.OOMKilled}} restarts={{.RestartCount}} (before: $restarts_before)"