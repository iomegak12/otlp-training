#!/usr/bin/env bash
# Installs k3s: server on <prefix>-cp, agents on the workers, then writes a kubeconfig for this laptop.
#  - Traefik is disabled (Grafana and Prometheus are reached on NodePorts).
#  - The control plane is tainted, so workloads run on the three workers only.
#  - k3s brings metrics-server (needed by the autoscaler) and the local-path storage class.
source "$(dirname "$0")/../scripts/common.sh"
require multipass kubectl

CP="${VM_PREFIX}-cp"
CP_IP=$(multipass exec "$CP" -- hostname -I | awk '{print $1}' | tr -d '\r')
step "Installing the k3s server on $CP ($CP_IP)"
multipass exec "$CP" -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server \
  --disable traefik --write-kubeconfig-mode 644 --tls-san $CP_IP \
  --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule"

TOKEN=$(multipass exec "$CP" -- sudo cat /var/lib/rancher/k3s/server/node-token | tr -d '\r\n')

for i in $(seq 1 "$WORKER_COUNT"); do
  W="${VM_PREFIX}-w${i}"
  step "Joining $W"
  multipass exec "$W" -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable \
    K3S_URL=https://$CP_IP:6443 K3S_TOKEN=$TOKEN sh -s - agent"
done

step "Writing kubeconfig to $KUBECONFIG_FILE"
mkdir -p "$(dirname "$KUBECONFIG_FILE")"
multipass exec "$CP" -- sudo cat /etc/rancher/k3s/k3s.yaml | tr -d '\r' \
  | sed "s/127.0.0.1/$CP_IP/; s/: default$/: tradenova-day3/" > "$KUBECONFIG_FILE"

kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide
echo
echo "Use this cluster from any terminal with:  export KUBECONFIG=$KUBECONFIG_FILE"
echo "Next: services/build-and-push.sh, then helm/install-platform.sh"
