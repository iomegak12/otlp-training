#!/usr/bin/env bash
# Shows what the OpenTelemetry Operator injected into a running pod.
#   labs/lab1-agent-gateway-scaling/show-injection.sh trade-api | portfolio-service | notification-service
source "$(dirname "$0")/../../scripts/common.sh"
app="${1:-trade-api}"
pod=$(kubectl get pods -n tradenova -l "app=$app" -o jsonpath='{.items[0].metadata.name}')
[[ -n "$pod" ]] || { echo "No pod found for app=$app"; exit 1; }

step "$pod: annotation (the opt-in)"
kubectl get pod "$pod" -n tradenova -o jsonpath='{.metadata.annotations}' | tr ',' '\n' | grep instrumentation || true

step "$pod: init containers added by the Operator (they copy the agent / SDK into a shared volume)"
kubectl get pod "$pod" -n tradenova \
  -o jsonpath='{range .spec.initContainers[*]}{.name}{"   "}{.image}{"\n"}{end}'

step "$pod: environment added to the application container"
kubectl get pod "$pod" -n tradenova \
  -o jsonpath='{range .spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
  | grep -E '^(OTEL_|JAVA_TOOL_OPTIONS|NODE_OPTIONS|PYTHONPATH)' | cut -c1-150 || true
