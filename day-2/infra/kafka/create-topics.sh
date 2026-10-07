#!/bin/sh
# Creates the Kafka topic used as the log buffer (scenario 5). Runs once at start-up.
set -e
BOOTSTRAP=kafka:9092
TOPICS=/opt/kafka/bin/kafka-topics.sh

echo "Waiting for Kafka ..."
until $TOPICS --bootstrap-server $BOOTSTRAP --list > /dev/null 2>&1; do
  sleep 2
done

# 3 partitions: up to 3 gateway Collectors could share the work.
# retention.ms = 24 hours: how long logs can wait in Kafka if Loki is unavailable.
$TOPICS --bootstrap-server $BOOTSTRAP --create --if-not-exists \
  --topic tradenova-logs --partitions 3 --replication-factor 1 \
  --config retention.ms=86400000

$TOPICS --bootstrap-server $BOOTSTRAP --describe --topic tradenova-logs
