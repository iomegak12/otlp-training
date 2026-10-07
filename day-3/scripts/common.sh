#!/usr/bin/env bash
# Shared setup for every script: settings, Git Bash quirks, kubectl/helm configuration.
# Usage (inside a script):  source "$(dirname "$0")/../scripts/common.sh"
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_ROOT"

# shellcheck disable=SC1091
source <(tr -d '\r' < "$LAB_ROOT/lab.env")   # tolerate Windows line endings

# Git Bash on Windows rewrites arguments that start with "/" into Windows paths
# (for example /opt/kafka/bin/... inside a container). Switch that off.
export MSYS_NO_PATHCONV=1

# kubectl and helm on Windows are native programs: give them a C:/... style path.
if command -v cygpath > /dev/null 2>&1; then
  KUBECONFIG="$(cygpath -m "$KUBECONFIG_FILE")"
  export KUBECONFIG
else
  export KUBECONFIG="$KUBECONFIG_FILE"
fi

# Print a heading
step() { printf '\n\033[1;36m>>> %s\033[0m\n' "$*"; }

LIGHT_MODE="${LIGHT_MODE:-0}"

# Apply a manifest after replacing the image registry placeholders.
# In the light kit, every application runs one replica instead of two.
render() {
  local light='s#^  replicas: 2$#  replicas: 2#'
  [[ "$LIGHT_MODE" == "1" ]] && light='s#^  replicas: 2$#  replicas: 1#'
  sed -e "s#__REGISTRY__#${REGISTRY}#g" -e "s#__IMAGE_TAG__#${IMAGE_TAG}#g" -e "$light" "$1"
}
apply_rendered() { render "$1" | kubectl apply -f -; }

delete_rendered() { render "$1" | kubectl delete --ignore-not-found -f -; }

# The Multipass VMs that run workloads (the agents' disk queues live on them).
node_vms() {
  if [[ "$LIGHT_MODE" == "1" ]]; then echo "${VM_PREFIX}-solo"
  else for i in $(seq 1 "$WORKER_COUNT"); do echo "${VM_PREFIX}-w${i}"; done; fi
}

require() {
  for tool in "$@"; do
    command -v "$tool" > /dev/null 2>&1 || { echo "Missing tool: $tool (see docs/Day3-Pre-Session-Checklist.md)"; exit 1; }
  done
}

# Kubernetes minor version of the cluster (for example 35 for v1.35).
kube_minor() {
  { kubectl version -o json 2>/dev/null | grep -A8 '"serverVersion"' | grep '"minor"' | head -1 | tr -dc '0-9'; } || true
}

# Apply a Collector or Instrumentation file. "trafficDistribution: PreferSameNode" (send each
# application to the agent on its own node) needs Kubernetes 1.35 or later; older clusters
# get the file without it (applications then reach any agent).
apply_otel() {
  local minor; minor=$(kube_minor)
  if [[ -n "$minor" && "$minor" -lt 35 ]]; then
    sed '/trafficDistribution: PreferSameNode/d' "$1" | kubectl apply -f -
  else
    kubectl apply -f "$1"
  fi
}

# IP address of a node (NodePorts answer on every node). Prefers a worker.
node_ip() {
  local ip
  ip=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
  [[ -n "$ip" ]] || ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  echo "$ip"
}

GRAFANA_PORT=30300
PROMETHEUS_PORT=30090
GRAFANA_AUTH="admin:tradenova"

# Run a command inside the test-client toolbox pod (created on first use).
ensure_test_client() {
  if ! kubectl get pod test-client -n tradenova > /dev/null 2>&1; then
    kubectl apply -f k8s/security/test-client.yaml > /dev/null
  fi
  kubectl wait --for=condition=Ready pod/test-client -n tradenova --timeout=180s > /dev/null
}
in_test_client() { kubectl exec -n tradenova test-client -- "$@"; }

# Kafka broker pod used for the Kafka command-line tools.
KAFKA_POD=tradenova-dual-role-0
kafka_tool() { kubectl exec -n kafka "$KAFKA_POD" -c kafka -- "$@"; }

# Wait until a resource created by an operator exists (for example the gateway StatefulSet).
wait_exists() {
  local i
  for i in $(seq 1 90); do
    kubectl get "$1" -n "$2" > /dev/null 2>&1 && return 0
    sleep 2
  done
  echo "Timed out waiting for $1 in namespace $2"; return 1
}

# Wait for the Collectors after a change (the Operator rolls the pods when the config changes).
wait_collectors() {
  wait_exists daemonset/otel-agent-collector observability
  wait_exists statefulset/otel-gateway-collector observability
  sleep 3
  kubectl rollout status daemonset/otel-agent-collector -n observability --timeout=300s
  kubectl rollout status statefulset/otel-gateway-collector -n observability --timeout=600s
}
