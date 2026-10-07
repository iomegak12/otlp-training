#!/usr/bin/env bash
# Creates the four Multipass VMs: <prefix>-cp (control plane) and <prefix>-w1..w3 (workers).
# Sizes come from lab.env. Takes about 5 minutes.
source "$(dirname "$0")/../scripts/common.sh"
require multipass

step "Creating ${VM_PREFIX}-cp (control plane: ${CP_CPUS} CPU, ${CP_MEMORY} RAM)"
multipass launch "$VM_IMAGE" --name "${VM_PREFIX}-cp" --cpus "$CP_CPUS" --memory "$CP_MEMORY" \
  --disk "$CP_DISK" --cloud-init 00-cluster/cloud-init.yaml

for i in $(seq 1 "$WORKER_COUNT"); do
  step "Creating ${VM_PREFIX}-w${i} (worker: ${WORKER_CPUS} CPU, ${WORKER_MEMORY} RAM)"
  multipass launch "$VM_IMAGE" --name "${VM_PREFIX}-w${i}" --cpus "$WORKER_CPUS" --memory "$WORKER_MEMORY" \
    --disk "$WORKER_DISK" --cloud-init 00-cluster/cloud-init.yaml
done

multipass list
echo "Next: 00-cluster/install-k3s.sh"
