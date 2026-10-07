#!/usr/bin/env bash
# Lab 2: what is waiting in each gateway's sending queues, and the disks behind them.
#   --short   only the queue sizes
#   --watch   refresh every 5 seconds (Ctrl+C to stop)
source "$(dirname "$0")/../../scripts/common.sh"
if [[ "${1:-}" == "--watch" ]]; then
  while true; do
    out=$("$LAB_ROOT/labs/lab2-persistent-queues/queue-status.sh" --short 2>&1)
    clear; echo "=== $(date +%H:%M:%S)  gateway sending queues (Ctrl+C to stop)"; echo "$out"
    sleep 5
  done
fi
for pod in $(kubectl get pods -n observability -l app.kubernetes.io/name=otel-gateway-collector -o name); do
  pod="${pod#pod/}"
  kubectl get --raw "/api/v1/namespaces/observability/pods/${pod}:8888/proxy/metrics" 2>/dev/null \
    | grep '^otelcol_exporter_queue_size' \
    | sed -E 's/.*data_type="([a-z]+)".*exporter="([^"]+)".*\} (.*)/\2 \1 \3/' \
    | awk -v p="$pod" '{printf "  %-26s %-28s %-8s queued batches: %s\n", p, $1, $2, $3}' || true
done
[[ "${1:-}" == "--short" ]] && exit 0
echo
echo "Disks (one PVC per gateway, kept when the pod dies or the gateway scales in):"
kubectl get pvc -n observability
