#!/usr/bin/env bash
# Lab 2: kill every gateway pod at once (a node failure, an eviction, a bad deploy...).
# The StatefulSet recreates them with the SAME disks (PVCs queue-otel-gateway-collector-N).
source "$(dirname "$0")/../../scripts/common.sh"
step "Queue sizes BEFORE the kill"
"$LAB_ROOT/labs/lab2-persistent-queues/queue-status.sh" --short
step "Killing all gateway pods"
kubectl delete pod -n observability -l app.kubernetes.io/name=otel-gateway-collector --wait=false
sleep 15
kubectl wait --for=condition=Ready pod -n observability -l app.kubernetes.io/name=otel-gateway-collector --timeout=300s
sleep 10
step "Queue sizes AFTER the restart"
"$LAB_ROOT/labs/lab2-persistent-queues/queue-status.sh" --short
