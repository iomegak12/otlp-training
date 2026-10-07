#!/usr/bin/env bash
# Lab 3 backup: imports the finished "Collector health" dashboard into Grafana.
# Use it if the live build runs out of time, or after Grafana restarts (it keeps no data).
source "$(dirname "$0")/../../scripts/common.sh"
require curl
import_to() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 -u "$GRAFANA_AUTH" -H 'Content-Type: application/json' \
    -X POST "$1/api/dashboards/db" --data-binary @labs/lab3-collector-health/dashboard-reference.json || true
}
url="http://$(node_ip):$GRAFANA_PORT"
code=$(import_to "$url")
if [[ "$code" != "200" ]]; then            # NodePort not reachable: try scripts/port-forward.sh's address
  url="http://localhost:3000"; code=$(import_to "$url")
fi
if [[ "$code" == "200" ]]; then
  echo "Imported: $url/d/tradenova-collector-health"
else
  echo "Import failed (HTTP $code). Is Grafana reachable at $url ? Try scripts/port-forward.sh and import"
  echo "labs/lab3-collector-health/dashboard-reference.json by hand (Dashboards -> New -> Import)."
  exit 1
fi
