#!/usr/bin/env bash
# Puts the platform in the state reached at the END of a lab, from any other state.
#
#   scripts/apply-lab.sh 0    starting state (same as scripts/reset-labs.sh)
#   scripts/apply-lab.sh 1    after Lab 1: notification-service deployed, gateway autoscaling (2-6)
#   scripts/apply-lab.sh 2    after Lab 2: persistent queues on agents and gateways
#   scripts/apply-lab.sh 3    after Lab 3: Lab 2 state + the reference Collector health dashboard
#   scripts/apply-lab.sh 4    after Lab 4: mTLS + token, Kafka TLS, allowlist, tenant routing
#
# To START lab N with a clean slate, apply the lab before it:  scripts/apply-lab.sh $((N-1))
#
# The files of that state are copied into k8s/collectors and k8s/instrumentation, so
# k8s/ always shows what is running. Open them in your editor to show the change.
source "$(dirname "$0")/common.sh"
require kubectl

N="${1:-}"
case "$N" in
  0)   src=labs/00-start/k8s ;;
  1)   src=labs/lab1-agent-gateway-scaling/after/k8s ;;
  2|3) src=labs/lab2-persistent-queues/after/k8s ;;
  4)   src=labs/lab4-security/after/k8s ;;
  *)   echo "Usage: $0 0|1|2|3|4"; exit 1 ;;
esac

step "Target state: after Lab $N (files from $src)"

# Leftovers from the labs
kubectl delete job burst-load -n tradenova --ignore-not-found > /dev/null
kubectl scale statefulset loki tempo -n monitoring --replicas=1 > /dev/null   # in case Lab 2's outage is still on

old_instr=$(grep -v '^#' k8s/instrumentation/instrumentation.yaml 2> /dev/null || true)
cp "$src/collectors/agent.yaml" "$src/collectors/gateway.yaml" k8s/collectors/
cp "$src/instrumentation/instrumentation.yaml" k8s/instrumentation/

step "Collectors"
apply_otel k8s/collectors/agent.yaml
apply_otel k8s/collectors/gateway.yaml

step "Instrumentation"
apply_otel k8s/instrumentation/instrumentation.yaml

if [[ "$N" -ge 1 ]]; then
  step "notification-service (deployed in Lab 1)"
  apply_rendered k8s/apps-later/notification-service.yaml
else
  step "Removing notification-service (it is deployed live in Lab 1)"
  delete_rendered k8s/apps-later/notification-service.yaml > /dev/null
fi

if [[ "$(grep -v '^#' k8s/instrumentation/instrumentation.yaml)" != "$old_instr" ]]; then
  step "Instrumentation changed: restarting the applications so the Operator re-injects them"
  sleep 3
  kubectl rollout restart deployment -n tradenova -l 'app in (trade-api,portfolio-service,notification-service)'
fi

step "Waiting for the Collectors"
wait_collectors
kubectl rollout status deployment/trade-api -n tradenova --timeout=300s
kubectl rollout status deployment/portfolio-service -n tradenova --timeout=300s
if [[ "$N" -ge 1 ]]; then
  kubectl rollout status deployment/notification-service -n tradenova --timeout=300s
fi

if [[ "$N" -ge 3 ]]; then
  step "Importing the reference Collector health dashboard"
  labs/lab3-collector-health/import-dashboard.sh || echo "(Dashboard not imported: run it again once Grafana is reachable.)"
fi

step "Now in the state after Lab $N"
kubectl get pods -n observability -o wide
kubectl get hpa -n observability 2> /dev/null || true
