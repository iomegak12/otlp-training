#!/usr/bin/env bash
# Lab 4: what does someone with network access to Kafka see? Reads 30 log messages from the
# otlp-logs topic on the PLAIN listener (9092) and pulls the e-mail addresses out of them.
source "$(dirname "$0")/../../scripts/common.sh"
step "Reading otlp-logs on port 9092 (no password, no certificate)"
kafka_tool /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic otlp-logs --max-messages 30 --timeout-ms 20000 2> /dev/null \
  | grep -a -o '[A-Za-z0-9._-]*@example\.com' | sort -u | head -10 || true
echo
echo "Customer e-mails, readable by anyone who can reach the broker."
echo "The gateway's allowlist runs AFTER Kafka, so Kafka itself must be protected."
