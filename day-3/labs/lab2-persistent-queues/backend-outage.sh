#!/usr/bin/env bash
# Lab 2: simulate a backend outage. Loki and Tempo go down (Prometheus stays up).
#   labs/lab2-persistent-queues/backend-outage.sh start
#   labs/lab2-persistent-queues/backend-outage.sh stop
source "$(dirname "$0")/../../scripts/common.sh"
case "${1:-}" in
  start)
    kubectl scale statefulset loki tempo -n monitoring --replicas=0
    echo "$(date +%H:%M:%S) Loki and Tempo are DOWN. Note the time: this is where a gap would start."
    echo "Gateways now hold logs and traces in their sending queues:  labs/lab2-persistent-queues/queue-status.sh" ;;
  stop)
    kubectl scale statefulset loki tempo -n monitoring --replicas=1
    kubectl rollout status statefulset/loki -n monitoring --timeout=300s
    kubectl rollout status statefulset/tempo -n monitoring --timeout=300s
    echo "$(date +%H:%M:%S) Loki and Tempo are back. The gateways now deliver what they queued." ;;
  *) echo "Usage: $0 start|stop"; exit 1 ;;
esac
