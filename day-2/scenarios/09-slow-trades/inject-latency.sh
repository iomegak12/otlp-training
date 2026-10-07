#!/usr/bin/env bash
# Scenario 9 trigger: make trade-api slow (default 800 ms per request).
#   inject-latency.sh          inject-latency.sh 1500        inject-latency.sh 0   (back to normal)
set -euo pipefail
ms="${1:-800}"
curl -s -X POST "http://localhost:8080/admin/chaos?latencyMs=$ms"; echo
