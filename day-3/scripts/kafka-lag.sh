#!/usr/bin/env bash
# How far behind are the gateways? Lag per topic and partition for the consumer group
# "otel-gateway", and which gateway pod (by IP) owns each partition.
source "$(dirname "$0")/common.sh"
require kubectl
kafka_tool /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group otel-gateway 2> /dev/null \
  | awk '/TOPIC/ || /otlp-/ {printf "%-14s %-10s %-8s %s\n", $2, $3, $6, $8}'
echo "(HOST is the gateway pod IP: compare with  kubectl get pods -n observability -o wide)"
