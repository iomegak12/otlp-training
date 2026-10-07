#!/usr/bin/env bash
# Lab 1A extra: get the Node.js console.log lines into Loki with a Collector-only change.
# The agent (one per node) reads the container's stdout file from the node and sends it down
# the same logs pipeline as OTLP logs. No change to the application or its image.
source scripts/common.sh

step "Before: the agent's logs pipeline only receives OTLP"
kubectl get otelcol otel-agent -n observability \
  -o jsonpath='{.spec.config.service.pipelines.logs.receivers}{"\n"}'

if kubectl get otelcol otel-agent -n observability -o jsonpath='{.spec.config.receivers}' | grep -q filelog; then
  echo "filelog is already configured."; exit 0
fi

step "Patching the agent: mount /var/log/pods, add a filelog receiver, add it to the logs pipeline"
kubectl patch otelcol otel-agent -n observability --type=json -p "$(cat <<'EOF'
[
  {"op":"add","path":"/spec/securityContext","value":{"runAsUser":0,"runAsGroup":0}},
  {"op":"add","path":"/spec/volumes/-","value":{"name":"varlogpods","hostPath":{"path":"/var/log/pods"}}},
  {"op":"add","path":"/spec/volumeMounts/-","value":{"name":"varlogpods","mountPath":"/var/log/pods","readOnly":true}},
  {"op":"add","path":"/spec/config/receivers/filelog","value":{
    "include":["/var/log/pods/tradenova_notification-service-*/*/*.log"],
    "include_file_path":true,
    "start_at":"end",
    "resource":{"service.name":"notification-service"},
    "operators":[{"type":"container"}]}},
  {"op":"add","path":"/spec/config/service/pipelines/logs/receivers/-","value":"filelog"}
]
EOF
)"

step "The Operator rolls the agents"
sleep 3
kubectl rollout status daemonset/otel-agent-collector -n observability --timeout=300s

step "After: two receivers feed the logs pipeline"
kubectl get otelcol otel-agent -n observability \
  -o jsonpath='{.spec.config.service.pipelines.logs.receivers}{"\n"}'

step "The agents that found a notification-service log file"
kubectl logs -n observability -l app.kubernetes.io/name=otel-agent-collector --tail=-1 --prefix \
  | grep -i "watching file" || echo "(none yet: give it a few seconds)"

echo
echo "In Grafana: Explore -> Loki (shared) -> {service_name=\"notification-service\"}"
echo "Wait about 1 minute. Open a line: k8s_pod_name and tradenova_team are there, a trace ID is not."
