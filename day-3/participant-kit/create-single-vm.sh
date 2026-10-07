#!/usr/bin/env bash
# Light kit: ONE Multipass VM running a single-node k3s (control plane and workloads together).
# Sizes come from lab.env (LIGHT_VM_*). Takes about 5 minutes.
source "$(dirname "$0")/../scripts/common.sh"
require multipass kubectl
VM="${VM_PREFIX}-solo"

if multipass info "$VM" > /dev/null 2>&1; then
  echo "$VM already exists."
else
  step "Creating $VM (${LIGHT_VM_CPUS} CPU, ${LIGHT_VM_MEMORY} RAM)"
  multipass launch "$VM_IMAGE" --name "$VM" --cpus "$LIGHT_VM_CPUS" --memory "$LIGHT_VM_MEMORY" \
    --disk "$LIGHT_VM_DISK" --cloud-init 00-cluster/cloud-init.yaml
fi

IP=$(multipass exec "$VM" -- hostname -I | awk '{print $1}' | tr -d '\r')
step "Installing k3s on $VM ($IP)"
multipass exec "$VM" -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server \
  --disable traefik --write-kubeconfig-mode 644 --tls-san $IP"

step "Writing kubeconfig to $KUBECONFIG_FILE"
mkdir -p "$(dirname "$KUBECONFIG_FILE")"
multipass exec "$VM" -- sudo cat /etc/rancher/k3s/k3s.yaml | tr -d '\r' \
  | sed "s/127.0.0.1/$IP/; s/: default$/: tradenova-day3/" > "$KUBECONFIG_FILE"
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide
