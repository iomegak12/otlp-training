# Security Policy

## This is training material

The TradeNova labs are built for a classroom, on a laptop or a private lab network. They are **not hardened and must not be used as a production deployment** or exposed to the internet.

Several things are insecure on purpose, because fixing them is part of the course or because it keeps the labs simple:

- **Open user interfaces.** Grafana, Prometheus, Jaeger, Alertmanager and the other tools are published on local ports without a login. In Days 1 and 2, Grafana gives anonymous users the admin role.
- **Personal data in telemetry.** Day 2 generates sample account numbers, e-mail addresses and card numbers in logs and traces so that scenario 3 can mask them.
- **Unencrypted, unauthenticated pipelines.** Telemetry travels in plain text with no authentication until Day 3, Lab 4, which adds mTLS, an ingest token and TLS to Kafka.
- **Shared demo credentials.** The `INGEST_TOKEN` in `day-3/lab.env` is a course default that every participant knows. It protects nothing outside the lab.
- **Mock cloud services.** Day 2 uses a mock AWS EC2 API. It needs no real AWS credentials; don't supply any.

## Using the labs safely

- Run them on a trusted network, and don't forward the lab ports to the internet.
- Don't send telemetry from real systems, or real customer data, into a lab stack.
- Log in to your container registry with `docker login`. Never write a registry password or access token into `lab.env` or any other tracked file.
- If you reuse a configuration from these labs elsewhere, replace every token and certificate, and add authentication to the user interfaces.
- Remove the lab when you are done: `docker compose down -v` for Days 1 and 2, `00-cluster/destroy-vms.sh` or `participant-kit/destroy-single-vm.sh` for Day 3.

## Supported versions

Only the latest version on the default branch is maintained.

## Reporting a vulnerability

The items listed above are known and intended. Please do report anything beyond them, for example:

- a real credential, key or token committed to the repository
- a script that could damage a participant's machine, or that affects anything outside the lab
- a lab step that leaves a participant's machine exposed after the lab has been removed
- a pinned image or dependency with a vulnerability that matters even in a classroom

**Don't open a public issue.** Use GitHub's private vulnerability reporting (the **Security** tab of the repository, then **Report a vulnerability**), or contact the maintainer, [@iomegak12](https://github.com/iomegak12), privately.

Include the day and file affected, how to reproduce the problem and what the impact could be. You should get an acknowledgement within a week.
