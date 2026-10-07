#!/usr/bin/env bash
# Lab 4: the TLS listener (9093) only talks to clients with a certificate signed by Strimzi's clients CA.
#   1. openssl without a client certificate      -> the broker ends the handshake
#   2. which listener the Collectors use now      -> 9093 with their own KafkaUser certificate
source "$(dirname "$0")/../../scripts/common.sh"
ensure_test_client
step "1. Connecting to Kafka's TLS port without a client certificate"
in_test_client sh -c 'echo | timeout 10 openssl s_client -connect tradenova-kafka-bootstrap.kafka.svc.cluster.local:9093 2>&1 \
  | grep -iE "alert|certificate required|handshake failure|verify return|Verification" | head -5' || true
step "2. Brokers the Collectors are configured with"
for c in otel-agent otel-gateway; do
  printf '  %-13s ' "$c"
  kubectl get opentelemetrycollector "$c" -n observability -o jsonpath='{.spec.config.receivers.kafka.brokers}{.spec.config.exporters.kafka.brokers}'
  echo
done
step "3. Their Kafka identities (KafkaUser -> certificate secret)"
kubectl get kafkauser -n observability
