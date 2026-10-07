# TradeNova Day 2: From Pilot to Platform

## The nine scenarios

| # | TradeNova problem | What fixes it |
| --- | --- | --- |
| 1 | Telemetry arrives with no environment, team or region | Enrichment processors in the agent |
| 2 | A market-open spike kills the pipeline | memory_limiter, batch, GOMEMLIMIT |
| 3 | Account numbers, e-mails and card numbers in logs and traces | OTTL masking in the agent |
| 4 | Paying for health checks, DEBUG logs and per-account series | filter and metrics_transform processors |
| 5 | A Loki outage loses logs | Kafka buffer between agent and gateway Collectors |
| 6 | The nightly batch job fails silently | Pushgateway |
| 7 | The cloud fleet scales; the target list doesn't | EC2 service discovery and relabeling |
| 8 | Nobody is told when things break | Prometheus alert rules, Alertmanager, e-mail |
| 9 | A trade is slow; which hop? | Tempo metrics generator, service graph, TraceQL |

## What runs

| Component | Image / technology | Port on localhost |
| --- | --- | --- |
| trade-api | Java 21, Spring Boot, OpenTelemetry Java agent 2.32.0 | 8080 |
| portfolio-service | Python, Flask, zero-code instrumentation | 8000 |
| eod-reconciliation | Python batch job (Pushgateway) | |
| loadgen | Python load generator (traffic and health checks) | |
| otel-agent | OpenTelemetry Collector contrib 0.161.0 | 4317, 4318 |
| otel-gateway | OpenTelemetry Collector contrib 0.161.0 (Kafka → Loki) | |
| kafka | Apache Kafka 4.3.1 (KRaft, single node) | |
| loki | Grafana Loki 3.7.8 | 3100 |
| tempo | Grafana Tempo 2.10.8 | 3200 |
| prometheus | Prometheus 3.14.0 (remote-write receiver on) | 9090 |
| pushgateway | Prometheus Pushgateway 1.11.3 | 9091 |
| alertmanager | Alertmanager 0.34.1 | 9093 |
| mailpit | Mailpit 1.31.4 (local e-mail inbox) | 8025 |
| grafana | Grafana 12.4.11 (anonymous admin) | 3000 |
| node-exporter, market-data-1..5 | Node exporter 1.12.1 | |
| fake-aws | Moto 5.2.3 (mock AWS EC2 API) | |
| telemetrygen | Spike generator (scenario 2, profile `spike`) | |

## Folder layout

```
docker-compose.yml          the whole stack
.env                        scenario switches (batch job, GOMEMLIMIT, load)
services/                   trade-api, portfolio-service, eod-reconciliation, loadgen
collector/agent/            agent configuration (starts in the "problem" state)
collector/gateway/          gateway configuration (Kafka → Loki)
infra/                      Prometheus (+ alert rules), Alertmanager, Loki, Tempo, Kafka, fake AWS, Grafana
scenarios/00-start/         the starting state of every file a scenario changes
scenarios/0N-*/after/       the finished state after scenario N (cumulative)
scenarios/0N-*/*.sh         triggers: spike, Loki outage, Kafka lag, failures, fleet size, latency
scripts/                    apply-scenario and reset-to-start (bash and PowerShell)
```

## Everyday commands

| Task | Command |
| --- | --- |
| Start | `docker compose up -d --build` |
| Jump to the end of scenario N | `scripts/apply-scenario.sh N` |
| Back to the starting state | `scripts/reset-to-start.sh` |
| Change the simulated EC2 fleet | `docker compose run --rm fleet scale 5` |
| Reload Prometheus after editing its config | `curl -X POST http://localhost:9090/-/reload` |
| Reload the agent after editing its config | `docker compose restart otel-agent` |
| Apply a change to `.env` | `docker compose up -d` |
| Stop | `docker compose down` (add `-v` to delete stored data) |

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| Containers exit or restart repeatedly | Not enough memory for Docker. Give it 10–12 GB. |
| trade-api build fails downloading dependencies | No access to Maven Central (proxy or firewall). |
| `telemetrygen` image cannot be pulled | No access to ghcr.io. Pull it on another network beforehand, or demonstrate scenario 2 with the runbook fallback. |
| No metrics from the services in Prometheus | `docker compose logs otel-agent`. Remote write needs Prometheus' `--web.enable-remote-write-receiver` flag (already set). |
| No market-data targets after scenario 7 | `docker compose run --rm fleet status` should list running instances. Prometheus refreshes discovery every 15 seconds. |
| No e-mails | Rules are loaded only after scenario 8. Check http://localhost:9093 for active alerts. |
| Service graph empty | Only after scenario 9, and only once traffic has flowed for a minute or two. |
| Collector logs warn about deprecated names | Not expected with this config. The current names are `otlp_grpc`, `otlp_http`, `prometheus_remote_write`, `metrics_transform` and `resource_detection`. |
