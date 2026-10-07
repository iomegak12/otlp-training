# OpenTelemetry Training: TradeNova Labs

Hands-on lab material for a three-day OpenTelemetry course. Every lab uses the same fictional trading company, **TradeNova**, and follows it from a first instrumented service to a secured telemetry platform on Kubernetes.

Each day is a self-contained kit in its own folder, with its own README. This page gives the overview; the day folders hold the commands.

## The three days

| Day | Theme | Runs on | Lab format | Guide |
| --- | --- | --- | --- | --- |
| 1 | Instrumenting services and reading the signals | Docker Compose | Labs A to E | [day-1/README.md](day-1/README.md) |
| 2 | From pilot to platform: running the Collector pipeline | Docker Compose | Nine scenarios | [day-2/README.md](day-2/README.md) |
| 3 | OpenTelemetry in production on Kubernetes | k3s on Multipass VMs | Labs 1 to 4 | [day-3/README.md](day-3/README.md) |

### Day 1: TradeNova OpenTelemetry Lab Kit

Three services send traces, metrics and logs through one OpenTelemetry Collector into Jaeger, Prometheus and Loki, viewed in Grafana. Each service shows a different way to instrument:

- `order-service`: Java 21 and Spring Boot, with the OpenTelemetry Java agent
- `quote-service`: Python and Flask, with zero-code instrumentation
- `settlement-service`: Python, with manual SDK instrumentation

Lab A sends OTLP by hand with a short Python script. Labs B to E change the service settings in `config/*.env` and the service code; Lab D fixes context propagation bugs that are built into `settlement-service`. The finished state of each lab is in `solutions/`, and `scripts/catch-up` jumps to any of them.

### Day 2: From Pilot to Platform

The pilot grows into a shared platform, and nine problems appear. Each scenario starts from the problem and ends with the fix:

| # | Problem | What fixes it |
| --- | --- | --- |
| 1 | Telemetry arrives with no environment, team or region | Enrichment processors in the agent |
| 2 | A market-open spike kills the pipeline | `memory_limiter`, `batch`, `GOMEMLIMIT` |
| 3 | Account numbers, e-mails and card numbers in logs and traces | OTTL masking in the agent |
| 4 | Paying for health checks, DEBUG logs and per-account series | `filter` and `metrics_transform` processors |
| 5 | A Loki outage loses logs | Kafka buffer between agent and gateway Collectors |
| 6 | The nightly batch job fails silently | Pushgateway |
| 7 | The cloud fleet scales; the target list doesn't | EC2 service discovery and relabeling |
| 8 | Nobody is told when things break | Prometheus alert rules, Alertmanager, e-mail |
| 9 | A trade is slow; which hop? | Tempo metrics generator, service graph, TraceQL |

The stack is an agent Collector and a gateway Collector with Kafka between them, plus Loki, Tempo, Prometheus, Alertmanager and Grafana. `scripts/apply-scenario` jumps to the end of any scenario and `scripts/reset-to-start` goes back to the beginning.

### Day 3: OpenTelemetry in Production on Kubernetes

TradeNova's services move to a four-node k3s cluster and are instrumented by the OpenTelemetry Operator:

```
apps (Java, Python, Node.js) ──OTLP──▶ agent (DaemonSet) ──▶ Kafka ──▶ gateways (StatefulSet + HPA) ──▶ Tempo / Loki / Prometheus ──▶ Grafana
```

| Lab | Topic |
| --- | --- |
| 1 | Auto-instrumentation with the Operator, then scaling the agent and gateway tiers |
| 2 | Persistent queues, so an outage or a crash does not lose telemetry |
| 3 | Collector health: a dashboard built live, and three broken pipelines to diagnose |
| 4 | Security and governance: mTLS, tokens, TLS to Kafka, attribute allowlist, tenant routing |

The instructor runs the full cluster during the session. Participants can replay every lab afterwards on one virtual machine with the light kit: [day-3/participant-kit/README-participants.md](day-3/participant-kit/README-participants.md).

## What you need

| | Day 1 | Day 2 | Day 3 |
| --- | --- | --- | --- |
| Runtime | Docker with Compose v2 | Docker with Compose v2 | Multipass, kubectl, Helm, Git Bash on Windows |
| Memory | 8 GB for Docker (6 GB minimum) | 10 to 12 GB for Docker | 16 GB laptop for the participant light kit |
| Also | Python 3.10 or newer on the host, for Lab A | | A container registry and `docker login`, for the instructor |

All three days download images and packages on the first run. Do the first build or install before the session, on a network that can reach Docker Hub, Maven Central, PyPI and ghcr.io.

## Getting started

```bash
git clone <repository-url>
cd otlp-training
```

Then open the README of the day you want and follow it. In short:

```bash
# Day 1
cd day-1
docker compose --profile load build
docker compose up -d

# Day 2
cd day-2
docker compose up -d --build

# Day 3 (participants): set LIGHT_MODE=1 and REGISTRY in lab.env first
cd day-3
participant-kit/install-all.sh
```

Days 1 and 2 use many of the same local ports (3000, 3100, 4317, 4318, 8000, 8080, 9090). Stop one day's stack before starting the other.

**Windows:** shell scripts must keep Unix line endings. Each day folder has a `.gitattributes` that takes care of this; if you still see `\r` errors, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Repository layout

```
day-1/    Lab kit: three services, one Collector, Jaeger, Prometheus, Loki, Grafana
day-2/    Platform kit: agent and gateway Collectors, Kafka, nine scenarios
day-3/    Kubernetes kit: cluster scripts, Helm values, manifests, labs, participant kit
```

## More

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): common problems, by day
- [CONTRIBUTING.md](CONTRIBUTING.md): how to report a problem or propose a change
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md): what this kit is safe for, and how to report a vulnerability
- [CHANGELOG.md](CHANGELOG.md)

## License

Released under the [MIT License](LICENSE).
