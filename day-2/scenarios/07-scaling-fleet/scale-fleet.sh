#!/usr/bin/env bash
# Scenario 7: change the size of the simulated EC2 market-data fleet (0-5).
#   scale-fleet.sh 5      scale-fleet.sh 2      scale-fleet.sh status
set -euo pipefail
cd "$(dirname "$0")/../.."
if [[ "${1:-status}" == "status" ]]; then
  docker compose run --rm fleet status
else
  docker compose run --rm fleet scale "$1"
fi
