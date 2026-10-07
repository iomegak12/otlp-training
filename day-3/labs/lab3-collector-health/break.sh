#!/usr/bin/env bash
# Lab 3: break the gateway pipeline in one of three ways. Do NOT say which one: find it on the dashboard.
#   labs/lab3-collector-health/break.sh 1|2|3
# Starts from the Lab 2 state (scripts/apply-lab.sh 2). Repair with fix.sh.
source "$(dirname "$0")/../../scripts/common.sh"
n="${1:-}"
[[ "$n" =~ ^[123]$ ]] || { echo "Usage: $0 1|2|3"; exit 1; }
apply_otel "labs/lab3-collector-health/broken-$n/gateway.yaml"
wait_collectors > /dev/null
echo "$(date +%H:%M:%S) Incident $n is live. Give it 2-3 minutes, then go to the dashboard."
