#!/usr/bin/env bash
# One-screen health check of the Day 3 platform.
source "$(dirname "$0")/common.sh"
require kubectl

step "Nodes"
kubectl get nodes
step "TradeNova applications"
kubectl get pods -n tradenova -o wide
step "Collectors (agents: one per worker; gateways: StatefulSet)"
kubectl get opentelemetrycollectors -n observability
kubectl get pods -n observability -o wide
kubectl get hpa -n observability 2> /dev/null || true
step "Kafka"
kubectl get kafka,kafkanodepool -n kafka
kubectl get pods -n kafka
step "Backends"
kubectl get pods -n monitoring
step "Consumer lag (gateways)"
"$LAB_ROOT/scripts/kafka-lag.sh" || echo "(Kafka tools not reachable yet)"
step "Where to look"
"$LAB_ROOT/scripts/urls.sh"
