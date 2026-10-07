#!/usr/bin/env bash
# Deletes the four lab VMs and everything in them (the most complete reset there is).
source "$(dirname "$0")/../scripts/common.sh"
require multipass
read -r -p "Delete VMs ${VM_PREFIX}-cp and ${VM_PREFIX}-w1..w${WORKER_COUNT}? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
multipass delete "${VM_PREFIX}-cp" $(for i in $(seq 1 "$WORKER_COUNT"); do echo "${VM_PREFIX}-w${i}"; done)
multipass purge
rm -f "$KUBECONFIG_FILE"
multipass list
