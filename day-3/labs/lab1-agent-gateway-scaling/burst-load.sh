#!/usr/bin/env bash
# Lab 1: the "market open" burst. Floods the agents with traces so the gateways get busy.
#   labs/lab1-agent-gateway-scaling/burst-load.sh [traces-per-second-per-pod] [duration] [pods]
#   default: 4 generator pods at rate 20000 = about 60,000 spans per second, for 6 minutes.
# One telemetrygen pod tops out at about 15,000 spans per second whatever the rate, so the load
# comes from the number of pods. If the gateways do not fall behind on your laptop, add pods:
#   burst-load.sh 20000 6m 6
# After Lab 4 the agent needs a certificate and a token: the script switches to the secure job.
source "$(dirname "$0")/../../scripts/common.sh"
DEFAULT_RATE=20000; DEFAULT_PODS=4
[[ "$LIGHT_MODE" == "1" ]] && { DEFAULT_RATE=300; DEFAULT_PODS=1; }   # light kit: one small node
RATE="${1:-$DEFAULT_RATE}"; DURATION="${2:-6m}"; PODS="${3:-$DEFAULT_PODS}"

job=k8s/jobs/burst-load.yaml
endpoint=$(kubectl get instrumentation tradenova -n tradenova -o jsonpath='{.spec.exporter.endpoint}')
if [[ "$endpoint" == https* ]]; then job=k8s/jobs/burst-load-secure.yaml; fi

kubectl delete job burst-load -n tradenova --ignore-not-found > /dev/null
sed -e "s/__RATE__/$RATE/" -e "s/__DURATION__/$DURATION/" -e "s/__PODS__/$PODS/g" "$job" | kubectl apply -f -
echo "Burst running: $PODS pod(s), rate $RATE each, for $DURATION ($(basename "$job"))."
echo "Watch it:  labs/lab1-agent-gateway-scaling/watch-scaling.sh"
echo "Stop it:   labs/lab1-agent-gateway-scaling/stop-burst.sh"
