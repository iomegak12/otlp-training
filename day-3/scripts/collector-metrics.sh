#!/usr/bin/env bash
# Reads a Collector's own metrics (port 8888) straight from the pod, without Prometheus.
#   scripts/collector-metrics.sh gateway [filter]     e.g. scripts/collector-metrics.sh gateway queue
#   scripts/collector-metrics.sh agent [filter]
source "$(dirname "$0")/common.sh"
require kubectl
which="${1:-gateway}"; filter="${2:-}"
for pod in $(kubectl get pods -n observability -l "app.kubernetes.io/name=otel-${which}-collector" -o name); do
  pod="${pod#pod/}"
  echo "=== $pod"
  kubectl get --raw "/api/v1/namespaces/observability/pods/${pod}:8888/proxy/metrics" \
    | grep -v '^#' | grep -E "otelcol_(receiver_accepted|receiver_refused|exporter_sent|exporter_send_failed|exporter_queue_size|exporter_enqueue_failed)" \
    | grep -E "${filter:-.}" | sed 's/,service_instance_id="[^"]*"//; s/,service_name="[^"]*"//; s/,service_version="[^"]*"//' || true
done
