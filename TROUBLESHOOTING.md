# Troubleshooting

Common problems in the TradeNova labs, grouped by day. Start with the first checks; most problems show up there.

## First checks

**Days 1 and 2 (Docker Compose)**, from the day folder:

```bash
docker compose ps                    # is everything running?
docker compose logs -f <service>     # what does the failing service say?
```

**Day 3 (Kubernetes)**, from `day-3`:

```bash
scripts/status.sh                              # what isn't running?
kubectl describe pod <name> -n <namespace>     # why not?
```

## All days

| Symptom | Likely cause and fix |
| --- | --- |
| Containers or pods restart, exit or are killed | Too little memory. Docker needs 8 GB for Day 1 and 10 to 12 GB for Day 2. The Day 3 light kit needs a 16 GB laptop. |
| A Java build fails downloading from Maven Central | Corporate proxy or firewall. Configure a Maven `settings.xml` mirror, or build on a network with direct access. |
| `pip install` fails during a Python image build | Corporate proxy. Pass it with `docker compose build --build-arg HTTPS_PROXY=http://proxy:port`. |
| A port is already in use | Another process has it, often the other day's stack: Days 1 and 2 share ports 3000, 3100, 4317, 4318, 8000, 8080 and 9090. Stop the other stack, or change the left-hand side of the port mapping in `docker-compose.yml`. |
| `\r` errors, or `<script>.sh: not found`, on Windows | The file was checked out with CRLF line endings. Re-clone with `git config core.autocrlf input`, or convert the file to LF. |
| A change to an `.env` file has no effect | `docker compose restart` does not reload environment files. Use `docker compose up -d <service>`. |

## Day 1

| Symptom | Likely cause and fix |
| --- | --- |
| No data anywhere | `docker compose logs otel-collector` for export errors, and `curl localhost:13133` for Collector health. |
| A metric disappeared from Prometheus | The Collector's Prometheus exporter drops series that have not been updated for 5 minutes. |
| `start.sh: not found` in quote-service | CRLF line endings; see "All days" above. |
| Grafana's "Open trace in Jaeger" link is missing | Copy the `trace_id` from the log line and paste it into Jaeger's search box. |
| Collector log shows deprecation warnings for `otlp` or `otlphttp` | Newer Collector versions are renaming these exporters. The warnings are harmless; the lab config keeps the long-standing names. |
| A lab went wrong and you want to move on | `scripts/catch-up.sh <b-e>` or `.\scripts\catch-up.ps1 -Lab <b-e>` copies the finished state of that lab. It overwrites your edits to the copied files. |
| You want a completely fresh start | `docker compose --profile load down -v`, then `docker compose up -d --build`. Lab edits are kept; stored data is deleted. |

## Day 2

| Symptom | Likely cause and fix |
| --- | --- |
| `telemetrygen` image cannot be pulled | No access to ghcr.io. Pull it on another network beforehand, or demonstrate scenario 2 with the runbook fallback. |
| No metrics from the services in Prometheus | `docker compose logs otel-agent`. Remote write needs Prometheus' `--web.enable-remote-write-receiver` flag, which is already set. |
| No market-data targets after scenario 7 | `docker compose run --rm fleet status` should list running instances. Prometheus refreshes discovery every 15 seconds. |
| No e-mails | Rules are loaded only after scenario 8. Check http://localhost:9093 for active alerts. |
| Service graph empty | It appears only after scenario 9, and only once traffic has flowed for a minute or two. |
| Collector logs warn about deprecated names | Not expected with this config. The current names are `otlp_grpc`, `otlp_http`, `prometheus_remote_write`, `metrics_transform` and `resource_detection`. |
| The files are in an unknown state | `scripts/reset-to-start.sh` returns to the starting state; `scripts/apply-scenario.sh N` jumps to the end of scenario N. |

## Day 3

| Symptom | Likely cause and fix |
| --- | --- |
| `ImagePullBackOff` | `REGISTRY` in `lab.env` doesn't match the registry the images were pushed to. Fix it, then run `helm/install-platform.sh`. |
| Pods `Pending`, "Insufficient memory" | Close other programs. On the light kit, give the VM more memory (`LIGHT_VM_MEMORY=10G`) and recreate it. |
| Grafana doesn't open | Run `scripts/port-forward.sh` and use http://localhost:3000. |
| Nothing works after restarting the VM (light kit) | The VM's IP address may have changed; Windows does this sometimes. Run `participant-kit/create-single-vm.sh` again. It keeps the VM and refreshes the connection. |
| No traces yet after an install or restart | Give it 5 minutes after an install, or 3 to 4 minutes after `multipass start`, then run `scripts/status.sh`. |
| The labs are in an unknown state | `scripts/reset-labs.sh` returns to the morning starting state and keeps data. Add `--wipe-queues` to empty the gateway and agent disk queues as well. |
| The platform itself is broken | `scripts/reset-everything.sh` uninstalls and reinstalls the platform; the VMs and k3s stay. `00-cluster/destroy-vms.sh` deletes the VMs for a complete reset. |

## Still stuck?

Open an issue and include the day, the lab or scenario, your operating system, the command you ran and the output of the first checks above. See [CONTRIBUTING.md](CONTRIBUTING.md).
