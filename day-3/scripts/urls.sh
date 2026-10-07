#!/usr/bin/env bash
# Prints the browser addresses of Grafana and Prometheus (NodePorts on the cluster nodes).
source "$(dirname "$0")/common.sh"
ip=$(node_ip)
echo "Grafana     http://$ip:$GRAFANA_PORT    (user admin / password tradenova; anonymous access is on)"
echo "Prometheus  http://$ip:$PROMETHEUS_PORT"
echo "If these do not open from your browser, use scripts/port-forward.sh instead."
