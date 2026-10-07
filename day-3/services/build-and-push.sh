#!/usr/bin/env bash
# Builds the five TradeNova images (linux/amd64) and pushes them to $REGISTRY (lab.env).
# Run `docker login` (Docker Hub) or `docker login ghcr.io` first. The Java build takes a few minutes.
source "$(dirname "$0")/../scripts/common.sh"
require docker

if [[ "$REGISTRY" == *CHANGE_ME* ]]; then
  echo "Set REGISTRY in lab.env first (for example docker.io/your-user)."; exit 1
fi

for svc in trade-api portfolio-service eod-reconciliation notification-service loadgen; do
  image="$REGISTRY/tradenova-$svc:$IMAGE_TAG"
  step "Building $image"
  docker build --platform linux/amd64 -t "$image" "services/$svc"
  docker push "$image"
done

step "Done. Images:"
for svc in trade-api portfolio-service eod-reconciliation notification-service loadgen; do
  echo "  $REGISTRY/tradenova-$svc:$IMAGE_TAG"
done
echo "On GHCR, make each package public (or create an image pull secret) so the cluster can pull it."
