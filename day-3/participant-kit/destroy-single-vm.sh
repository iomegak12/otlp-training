#!/usr/bin/env bash
# Light kit: deletes the single VM and everything in it.
source "$(dirname "$0")/../scripts/common.sh"
read -r -p "Delete the VM ${VM_PREFIX}-solo and everything in it? [y/N] " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || exit 0
multipass delete "${VM_PREFIX}-solo" && multipass purge
