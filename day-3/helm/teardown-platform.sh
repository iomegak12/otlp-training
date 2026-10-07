#!/usr/bin/env bash
# Removes everything install-platform.sh created (the VMs and k3s stay).
# Afterwards, helm/install-platform.sh rebuilds a clean platform in 15-20 minutes.
source "$(dirname "$0")/../scripts/common.sh"
require kubectl helm

read -r -p "Delete the whole TradeNova platform (applications, Collectors, Kafka, backends)? [y/N] " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || exit 0

step "Applications and Collectors"
kubectl delete namespace tradenova --ignore-not-found --wait=true
kubectl delete opentelemetrycollector --all -n observability --ignore-not-found
kubectl delete namespace observability --ignore-not-found --wait=true   # includes the gateway queues (PVCs)

step "Kafka"
kubectl delete kafkatopic --all -n kafka --ignore-not-found
kubectl delete kafka --all -n kafka --ignore-not-found --wait=true
kubectl delete kafkanodepool --all -n kafka --ignore-not-found --wait=true
helm uninstall strimzi -n kafka --ignore-not-found
kubectl delete namespace kafka --ignore-not-found --wait=true

step "Backends"
for r in grafana tempo loki prometheus; do helm uninstall "$r" -n monitoring --ignore-not-found; done
kubectl delete namespace monitoring --ignore-not-found --wait=true

step "Operator and cert-manager"
helm uninstall opentelemetry-operator -n opentelemetry-operator-system --ignore-not-found
kubectl delete namespace opentelemetry-operator-system --ignore-not-found
kubectl delete -f k8s/certs/ca-and-issuers.yaml --ignore-not-found
helm uninstall cert-manager -n cert-manager --ignore-not-found
kubectl delete namespace cert-manager --ignore-not-found

step "Agent queues on the nodes (hostPath /var/lib/otelcol)"
if command -v multipass > /dev/null 2>&1; then
  for vm in $(node_vms); do
    multipass exec "$vm" -- sudo rm -rf /var/lib/otelcol || true
  done
fi

echo "Platform removed. Custom resource definitions are kept (harmless)."
