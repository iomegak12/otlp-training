# TradeNova OpenTelemetry Lab Kit

## What's inside

| Path | What it is |
| --- | --- |
| `docker-compose.yml` | The whole stack: 3 services, load generator, Kafka, PostgreSQL, Collector, Jaeger, Prometheus, Loki, Grafana |
| `config/*.env` | OpenTelemetry settings per service. Most lab changes happen here |
| `collector/config.yaml` | OpenTelemetry Collector pipeline (OTLP in; Jaeger, Prometheus, Loki out) |
| `services/order-service` | Java 21, Spring Boot; OpenTelemetry Java agent 2.32.0 |
| `services/quote-service` | Python, Flask; zero-code instrumentation |
| `services/settlement-service` | Python; manual SDK instrumentation, with the Lab D propagation bugs |
| `services/loadgen` | Sends about 4 orders per second, with W3C baggage |
| `labs/lab-a/send_otlp.py` | Sends OTLP/JSON by hand (Python standard library only) |
| `solutions/after-lab-b` … `after-lab-e` | Finished state of each lab |
| `scripts/catch-up.sh`, `scripts/catch-up.ps1` | Copy a finished state and restart the stack |

## Requirements

- Docker Desktop or Docker Engine with Compose v2, and **at least 8 GB of memory for Docker** (6 GB minimum)
- Python 3.10 or newer on the host (only for `labs/lab-a/send_otlp.py`)
- Free local ports: 3000, 3100, 4317, 4318, 8000, 8080, 8889, 9090, 13133, 16686
- Internet access during the first build to: Docker Hub, Maven Central (`repo.maven.apache.org`), PyPI (`pypi.org`, `files.pythonhosted.org`)

## Before the session: build once

The first build downloads base images, Maven dependencies, the Java agent and Python packages. On a slow network this can take 10 minutes or more, so do it before the class starts:

```bash
docker compose --profile load build
docker compose pull
```

Then start the stack for Lab A:

```bash
docker compose up -d
docker compose ps
```

## Everyday commands

| Task | Command |
| --- | --- |
| Apply a change to `config/*.env` or `.env` | `docker compose up -d <service>` |
| Apply a source code change | `docker compose up -d --build <service>` |
| Start the load generator | `docker compose --profile load up -d loadgen` |
| Follow a service's log | `docker compose logs -f <service>` |
| Jump to the end of a lab | `scripts/catch-up.sh <b-e>` or `.\scripts\catch-up.ps1 -Lab <b-e>` |
| Stop everything | `docker compose --profile load down` |
| Start completely fresh (lab edits are kept; data is deleted) | `docker compose --profile load down -v` then `docker compose up -d --build` |

`docker compose restart` does **not** reload environment files. Always use `up -d`.

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| order-service build fails downloading from Maven Central | Corporate proxy or mirror. Configure a Maven `settings.xml` mirror, or build on a network with direct access. |
| `pip install` fails during a Python image build | Corporate proxy. Pass it with `docker compose build --build-arg HTTPS_PROXY=http://proxy:port`. |
| A port is already in use | Stop the other process, or change the left-hand side of that port mapping in `docker-compose.yml`. |
| Containers restart or are killed | Docker has too little memory. Raise it to 8 GB in Docker Desktop settings. |
| No data anywhere | `docker compose logs otel-collector` for export errors, and `curl localhost:13133` for Collector health. |
| A metric disappeared from Prometheus | The Collector's Prometheus exporter drops series that have not been updated for 5 minutes. |
| `start.sh: not found` or `\r` errors in quote-service (Windows) | The file was checked out with CRLF line endings. Re-clone with `git config core.autocrlf input`, or convert the file to LF. |
| Grafana's "Open trace in Jaeger" link is missing | Copy the `trace_id` from the log line and paste it into Jaeger's search box. |
| Collector log shows deprecation warnings for `otlp` or `otlphttp` | Newer Collector versions are renaming these exporters. The warnings are harmless; the lab config keeps the long-standing names. |
