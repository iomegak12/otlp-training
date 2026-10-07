#!/usr/bin/env bash
# Fallback if the NodePorts are not reachable from the laptop: forwards
#   http://localhost:3000 -> Grafana      http://localhost:9090 -> Prometheus
# Keep this terminal open. Ctrl+C stops both.
source "$(dirname "$0")/common.sh"
require kubectl
trap 'kill 0' EXIT INT TERM
kubectl port-forward -n monitoring svc/grafana 3000:80 &
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
echo "Grafana http://localhost:3000   Prometheus http://localhost:9090   (Ctrl+C to stop)"
wait
