#!/usr/bin/env bash
# Lab 1: one screen, refreshed every 10 seconds: autoscaler, gateway pods and CPU, Kafka lag.
# Ctrl+C to stop.
source "$(dirname "$0")/../../scripts/common.sh"
set +e
while true; do
  out=$(
    echo "=== $(date +%H:%M:%S)   (refresh every 10 s, Ctrl+C to stop)"
    echo
    echo "--- Autoscaler"
    kubectl get hpa -n observability 2>&1 | sed 's/^No resources found.*/(no autoscaler: fixed number of gateways)/'
    echo
    echo "--- Gateway pods (CPU limit 500m each)"
    kubectl top pods -n observability -l app.kubernetes.io/name=otel-gateway-collector 2>/dev/null \
      || kubectl get pods -n observability -l app.kubernetes.io/name=otel-gateway-collector
    echo
    echo "--- Kafka lag (messages waiting for the gateways)"
    kafka_tool /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
      --describe --group otel-gateway 2> /dev/null \
      | awk '/otlp-/ {lag[$2]+=$6; if ($7 != "-") c[$2" "$7]=1}
             END {for (t in lag) {n=0; for (k in c) if (index(k, t" ")==1) n++;
                  printf "  %-14s lag %-8d consumers %d\n", t, lag[t], n}}' | sort
  )
  clear
  echo "$out"
  sleep 10
done
