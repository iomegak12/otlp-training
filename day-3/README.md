# TradeNova Day 3 — OpenTelemetry in Production on Kubernetes

The Day 3 lab platform: TradeNova's services on a four-node k3s cluster, instrumented by the OpenTelemetry Operator, with an agent → Kafka → gateway Collector pipeline into Tempo, Loki and Prometheus, viewed in Grafana.

```
apps (Java, Python, Node.js) ──OTLP──▶ agent (DaemonSet) ──▶ Kafka (3 topics) ──▶ gateways (StatefulSet + HPA) ──▶ Tempo / Loki / Prometheus ──▶ Grafana
```

The full diagram is `docs/architecture.mmd`.

## The four labs

| Lab | Problem shown first | Fix |
| --- | --- | --- |
| 1A Auto-instrumentation | OpenTelemetry baked into every image; trade-api calls a service that doesn't exist yet | `Instrumentation` CR + one annotation per pod; deploy a Node.js service live |
| 1B Agent + gateway, scaling | One gateway falls behind during a burst (Kafka lag grows) | Gateway autoscaler 2–6, Kafka consumer group spreads the partitions |
| 2 Persistent queues | Backend outage + gateway crash = a hole in logs and traces | `file_storage` disk queues, `message_marking.after`, infinite retry |
| 3 Collector health | Partial pipeline failures are silent | Collector health dashboard built live; three broken pipelines to diagnose |
| 4 Security and governance | Anyone can send; plain text to Kafka; PII attributes; one shared tenant | mTLS + token into the agent, TLS client certs into Kafka, attribute allowlist, tenant routing |

## Folder structure

```
tradenova-day3-k8s/
├── lab.env                     ← the ONLY file to edit (REGISTRY, VM sizes, light mode)
├── 00-cluster/                 Multipass VMs + k3s (create, install, destroy)
├── services/                   source of the 5 images + build-and-push.sh (no OpenTelemetry inside)
├── helm/
│   ├── install-platform.sh     installs everything, in order
│   ├── teardown-platform.sh    removes everything (VMs stay)
│   └── values/                 one values file per Helm chart
├── k8s/                        what is RUNNING now (apply-lab.sh copies each lab state here)
│   ├── collectors/             agent + gateway OpenTelemetryCollector CRs, RBAC
│   ├── instrumentation/        the Instrumentation CR
│   ├── apps/  apps-later/      TradeNova workloads; notification-service (Lab 1)
│   ├── kafka/  certs/          Strimzi cluster, topics, users; cert-manager CA and certificates
│   └── jobs/  security/        telemetrygen burst jobs; test-client toolbox pod
├── labs/
│   ├── 00-start/               starting state
│   ├── lab1-…/ lab2-…/ lab4-…/ after/ = the finished state + the lab's demo scripts
│   └── lab3-collector-health/  broken-1..3, break.sh, fix.sh, reference dashboard
├── scripts/                    apply-lab, reset-labs, reset-everything, status, urls, kafka-lag, …
├── participant-kit/            single-node light kit for participants (16 GB laptops)
└── docs/
    ├── Day3-Architecture-Talk.md     20-minute talk on the diagram
    ├── Day3-Speaker-Script.md        ~10 minutes per lab: problem, approach, how it works, challenges, Datadog lens
    ├── Day3-Demo-Runbook.md          every command and click, lab by lab
    ├── Day3-Pre-Session-Checklist.md
    └── architecture.mmd
```

## Quick start (instructor)

All commands in **Git Bash**, from this folder. Details and checks: `docs/Day3-Pre-Session-Checklist.md`.

```bash
# 1. edit lab.env: REGISTRY=docker.io/<you>   then: docker login
00-cluster/create-vms.sh          # 4 VMs
00-cluster/install-k3s.sh         # k3s, kubeconfig
services/build-and-push.sh        # 5 images
helm/install-platform.sh          # everything else (15-20 min)
scripts/status.sh                 # check
scripts/urls.sh                   # Grafana :30300, Prometheus :30090
```

## Moving between labs, and resetting

| Command | Result |
| --- | --- |
| `scripts/apply-lab.sh N` | the state at the **end** of lab N (0–4), from any state. To start lab N, apply N-1. |
| `scripts/reset-labs.sh` | back to the morning starting state (keeps data) |
| `scripts/reset-labs.sh --wipe-queues` | same, and empties the gateway and agent disk queues |
| `scripts/reset-everything.sh` | uninstalls and reinstalls the whole platform (VMs and k3s stay) |
| `00-cluster/destroy-vms.sh` | deletes the VMs: the complete reset |

## Versions

k3s (stable channel) · OpenTelemetry Operator 0.160 (chart 0.124.1) · Collector contrib 0.161.0 · Strimzi 1.2.0, Kafka 4.3.1 · cert-manager v1.21.2 · Prometheus chart 29.35.0 · Loki chart 7.3.0 · Tempo 2.10.8 (chart 2.4.0) · Grafana chart 13.2.7.

## Participants

Give participants the bundle, plus your `REGISTRY` value. They follow `participant-kit/README-participants.md`: set `LIGHT_MODE=1` in `lab.env` and run `participant-kit/install-all.sh`.
