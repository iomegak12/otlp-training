#!/usr/bin/env bash
# Bring your lab folder to the finished state of a lab, then rebuild and restart the stack.
#
#   scripts/catch-up.sh b     # state after Lab B (also c, d or e)
#
# Your own edits to the copied files are overwritten. Files not in the snapshot are left alone.
set -euo pipefail
cd "$(dirname "$0")/.."

lab="${1:-}"
case "$lab" in
  b|c|d|e) ;;
  *) echo "Usage: scripts/catch-up.sh <b|c|d|e>"; exit 1 ;;
esac

echo "Copying solutions/after-lab-$lab into the lab folder:"
(cd "solutions/after-lab-$lab" && find . -type f | sed 's|^\./|  |')
cp -R "solutions/after-lab-$lab/." ./

echo "Rebuilding and restarting (the load generator is included) ..."
docker compose --profile load up -d --build
