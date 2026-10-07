#!/usr/bin/env bash
# Light kit, all in one: single VM + k3s + the whole Day 3 platform (30-40 minutes the first time).
# Before running: in lab.env set LIGHT_MODE=1 and REGISTRY to the value your instructor gave you.
source "$(dirname "$0")/../scripts/common.sh"
if [[ "$LIGHT_MODE" != "1" ]]; then
  echo "Set LIGHT_MODE=1 in lab.env first."; exit 1
fi
"$LAB_ROOT/participant-kit/create-single-vm.sh"
"$LAB_ROOT/helm/install-platform.sh"
