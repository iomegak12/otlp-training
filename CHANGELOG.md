# Changelog

Notable changes to the TradeNova OpenTelemetry training material are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are grouped by the day they affect.

## [Unreleased]

### Added

- **Repository**: root `README.md` with an overview of the three days, plus `CONTRIBUTING.md`, `TROUBLESHOOTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, the MIT `LICENSE` and a root `.gitignore`.
- **Day 1**: TradeNova OpenTelemetry Lab Kit. A Docker Compose stack with `order-service` (Java agent), `quote-service` (Python zero-code instrumentation), `settlement-service` (manual SDK instrumentation), a load generator, Kafka, PostgreSQL, one OpenTelemetry Collector, Jaeger, Prometheus, Loki and Grafana. Labs A to E, with finished states in `solutions/` and `scripts/catch-up` for bash and PowerShell.
- **Day 2**: From Pilot to Platform. A Docker Compose stack with agent and gateway Collectors, Kafka, Loki, Tempo, Prometheus, Pushgateway, Alertmanager, Mailpit, Grafana and a mock AWS EC2 API. Nine scenarios, with `scripts/apply-scenario` and `scripts/reset-to-start` for bash and PowerShell.
- **Day 3**: OpenTelemetry in Production on Kubernetes. A k3s cluster on Multipass VMs with the OpenTelemetry Operator, an agent to Kafka to gateway pipeline, Tempo, Loki, Prometheus and Grafana. Labs 1 to 4, with `scripts/apply-lab` and the reset scripts, and a single-VM light kit for participants.
