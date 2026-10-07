#!/usr/bin/env bash
# Stops the burst. The autoscaler waits 2 minutes (stabilization window) before removing gateways.
source "$(dirname "$0")/../../scripts/common.sh"
kubectl delete job burst-load -n tradenova --ignore-not-found
echo "Burst stopped. Keep watch-scaling.sh open: lag drains first, replicas drop about 2 minutes later."
