#!/usr/bin/env bash
# The big reset: removes the whole platform and installs it again (20-25 minutes).
# The VMs and k3s stay. To rebuild the VMs too: 00-cluster/destroy-vms.sh, then follow the checklist.
source "$(dirname "$0")/common.sh"
"$LAB_ROOT/helm/teardown-platform.sh"
"$LAB_ROOT/helm/install-platform.sh"
