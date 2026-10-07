#!/usr/bin/env bash
# Lab 3: repair the gateway (re-applies the healthy Lab 2 configuration and copies it to k8s/collectors/).
# Shows the difference between the broken and the healthy configuration first.
#   labs/lab3-collector-health/fix.sh [1|2|3]
source "$(dirname "$0")/../../scripts/common.sh"
HEALTHY=labs/lab2-persistent-queues/after/k8s/collectors/gateway.yaml
if [[ "${1:-}" =~ ^[123]$ ]]; then
  step "What was wrong (< broken, > healthy)"
  diff "labs/lab3-collector-health/broken-$1/gateway.yaml" "$HEALTHY" | grep -E '^[<>] ' | grep -v '^[<>] #' || true
fi
step "Applying the healthy gateway"
cp "$HEALTHY" k8s/collectors/gateway.yaml
apply_otel k8s/collectors/gateway.yaml
wait_collectors > /dev/null
echo "$(date +%H:%M:%S) Fixed. Watch the panels recover."
