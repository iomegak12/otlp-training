#!/usr/bin/env bash
# Back to the starting state of Day 3, without reinstalling anything (about 3 minutes):
# starting Collector and Instrumentation files, no notification-service, no lab leftovers.
#
# Kept on purpose: data in Kafka, Loki, Tempo and Prometheus, and the gateway disks (PVCs).
#   Wipe the gateway disk queues too:   scripts/reset-labs.sh --wipe-queues
#   Rebuild the whole platform:          scripts/reset-everything.sh
source "$(dirname "$0")/common.sh"
require kubectl

step "Removing lab leftovers"
kubectl delete pod test-client -n tradenova --ignore-not-found --wait=false
kubectl delete job burst-load -n tradenova --ignore-not-found

if [[ "${1:-}" == "--wipe-queues" ]]; then
  step "Wiping the gateway disk queues (the gateway restarts with empty disks)"
  kubectl delete opentelemetrycollector otel-gateway -n observability --ignore-not-found --wait=true
  for _ in $(seq 1 30); do
    [[ -z "$(kubectl get pods -n observability -l app.kubernetes.io/name=otel-gateway-collector -o name 2>/dev/null)" ]] && break
    sleep 2
  done
  for pvc in $(kubectl get pvc -n observability -o name | grep queue-otel-gateway-collector || true); do
    kubectl delete -n observability "$pvc"
  done
  if command -v multipass > /dev/null 2>&1; then
    for vm in $(node_vms); do
      multipass exec "$vm" -- sudo rm -rf /var/lib/otelcol/agent || true
    done
  fi
fi

"$LAB_ROOT/scripts/apply-lab.sh" 0
echo
echo "Reset done. Grafana dashboards you built live are kept until Grafana restarts."
