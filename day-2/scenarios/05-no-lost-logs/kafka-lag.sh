#!/usr/bin/env bash
# Scenario 5: show how many log records are waiting in Kafka for the gateway Collector (LAG column).
cd "$(dirname "$0")/../.."
docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group otel-gateway
