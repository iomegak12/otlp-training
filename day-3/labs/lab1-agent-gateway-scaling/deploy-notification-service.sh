#!/usr/bin/env bash
# Lab 1: deploy the Node.js notification-service live. Its image has no OpenTelemetry at all;
# the annotation instrumentation.opentelemetry.io/inject-nodejs does the work.
source "$(dirname "$0")/../../scripts/common.sh"
step "The only OpenTelemetry line in the manifest:"
grep -n "instrumentation.opentelemetry.io" k8s/apps-later/notification-service.yaml
step "Deploying"
apply_rendered k8s/apps-later/notification-service.yaml
kubectl rollout status deployment/notification-service -n tradenova --timeout=300s
"$LAB_ROOT/labs/lab1-agent-gateway-scaling/show-injection.sh" notification-service
echo
echo "In Grafana: Explore -> Tempo (shared) -> Search, service.name = notification-service."
echo "Open a trade-api POST /api/trades trace: the notification call now has Node.js spans under it."
