#!/usr/bin/env bash
# Installs the complete Day 3 platform on the k3s cluster, in order, and waits for each part.
# Safe to run again: every step is "install or upgrade". Takes 15-20 minutes the first time.
#
#   1. namespaces                                5. Prometheus, Loki, Tempo, Grafana
#   2. cert-manager + the lab CA and certificates 6. Collectors (agent DaemonSet, gateway StatefulSet)
#   3. OpenTelemetry Operator                    7. Instrumentation + TradeNova applications
#   4. Strimzi + Kafka (3 brokers, topics, users)
#
# The Lab 4 plumbing (certificates, Kafka users, token secrets) is created now but not USED until
# Lab 4: the starting state is plain OTLP, plain Kafka, one tenant.
source "$(dirname "$0")/../scripts/common.sh"
require kubectl helm

if [[ "$REGISTRY" == *CHANGE_ME* ]]; then
  echo "Set REGISTRY in lab.env first (and run services/build-and-push.sh)."; exit 1
fi
kubectl get nodes > /dev/null || { echo "Cannot reach the cluster. Run 00-cluster/install-k3s.sh first."; exit 1; }
minor=$(kube_minor)
echo "Kubernetes 1.${minor} detected."
if [[ -n "$minor" && "$minor" -lt 35 ]]; then
  echo "Note: node-local agent routing (PreferSameNode) needs 1.35+. It will be left out."
fi

# Light kit: smaller values on top of the normal ones, and a one-broker Kafka.
light() { [[ "$LIGHT_MODE" == "1" && -f "participant-kit/values-light/$1" ]] && echo "-f participant-kit/values-light/$1"; true; }
KAFKA_DIR=k8s/kafka
if [[ "$LIGHT_MODE" == "1" ]]; then KAFKA_DIR=participant-kit/kafka-light; echo "LIGHT MODE: single-node kit."; fi

step "1/7 Namespaces"
kubectl apply -f k8s/namespaces.yaml

step "Helm repositories"
helm repo add jetstack https://charts.jetstack.io --force-update > /dev/null
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts --force-update > /dev/null
helm repo add grafana-community https://grafana-community.github.io/helm-charts --force-update > /dev/null
helm repo update > /dev/null

step "2/7 cert-manager"
helm upgrade --install cert-manager jetstack/cert-manager --version v1.21.2 \
  -n cert-manager --create-namespace -f helm/values/cert-manager.yaml --wait --timeout 10m
kubectl apply -f k8s/certs/ca-and-issuers.yaml
kubectl wait --for=condition=Ready certificate/tradenova-telemetry-ca -n cert-manager --timeout=120s
kubectl apply -f k8s/certs/certificates.yaml
kubectl wait --for=condition=Ready certificate --all -n observability --timeout=120s
kubectl wait --for=condition=Ready certificate --all -n tradenova --timeout=120s

step "3/7 OpenTelemetry Operator"
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator --version 0.124.1 \
  -n opentelemetry-operator-system --create-namespace -f helm/values/opentelemetry-operator.yaml \
  --wait --timeout 10m

step "4/7 Strimzi and Kafka (the brokers take 3-5 minutes)"
helm upgrade --install strimzi oci://quay.io/strimzi-helm/strimzi-kafka-operator --version 1.2.0 \
  -n kafka -f helm/values/strimzi.yaml --wait --timeout 10m
kubectl apply -f "$KAFKA_DIR/kafka-cluster.yaml"
kubectl wait kafka/tradenova -n kafka --for=condition=Ready --timeout=15m
kubectl apply -f "$KAFKA_DIR/kafka-topics.yaml"
kubectl apply -f k8s/kafka/kafka-users.yaml
kubectl wait kafkatopic --all -n kafka --for=condition=Ready --timeout=300s
kubectl wait kafkauser --all -n observability --for=condition=Ready --timeout=300s

# The Collectors check the brokers' certificate (Lab 4) with Kafka's cluster CA: copy it next to them.
ca=$(kubectl get secret tradenova-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.crt}' | base64 -d)
kubectl create secret generic tradenova-cluster-ca-cert -n observability \
  --from-literal=ca.crt="$ca" --dry-run=client -o yaml | kubectl apply -f -

# The ingest token (Lab 4): the agent checks it, the applications send it.
for ns in observability tradenova; do
  kubectl create secret generic otel-ingest-token -n "$ns" \
    --from-literal=token="$INGEST_TOKEN" \
    --from-literal=header="x-tradenova-token=$INGEST_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
done

step "5/7 Prometheus, Loki, Tempo, Grafana"
helm upgrade --install prometheus prometheus-community/prometheus --version 29.35.0 \
  -n monitoring -f helm/values/prometheus.yaml $(light prometheus.yaml) --wait --timeout 10m
helm upgrade --install loki grafana/loki --version 7.3.0 \
  -n monitoring -f helm/values/loki.yaml $(light loki.yaml) --wait --timeout 10m
helm upgrade --install tempo grafana-community/tempo --version 2.4.0 \
  -n monitoring -f helm/values/tempo.yaml $(light tempo.yaml) --wait --timeout 10m
helm upgrade --install grafana grafana-community/grafana --version 13.2.7 \
  -n monitoring -f helm/values/grafana.yaml $(light grafana.yaml) --wait --timeout 10m

step "6/7 Collectors (starting state)"
mkdir -p k8s/collectors k8s/instrumentation
cp labs/00-start/k8s/collectors/agent.yaml labs/00-start/k8s/collectors/gateway.yaml k8s/collectors/
cp labs/00-start/k8s/instrumentation/instrumentation.yaml k8s/instrumentation/
kubectl apply -f k8s/collectors/rbac.yaml
apply_otel k8s/collectors/agent.yaml
apply_otel k8s/collectors/gateway.yaml
wait_collectors

step "7/7 Instrumentation and the TradeNova applications"
apply_otel k8s/instrumentation/instrumentation.yaml
sleep 5   # give the Operator's webhook a moment to see the new Instrumentation
for f in k8s/apps/*.yaml; do apply_rendered "$f"; done
kubectl rollout status deployment/trade-api -n tradenova --timeout=300s
kubectl rollout status deployment/portfolio-service -n tradenova --timeout=300s
kubectl rollout status deployment/loadgen -n tradenova --timeout=300s

step "Done"
scripts/urls.sh
echo
echo "Smoke test: scripts/status.sh (wait about 3 minutes for data in Grafana)."
