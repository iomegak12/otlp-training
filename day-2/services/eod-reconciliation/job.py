"""eod-reconciliation: TradeNova's end-of-day reconciliation batch job.

In production this runs once a night and exits after a few minutes. In the lab it runs every
EOD_INTERVAL_SECONDS (default 90) to simulate "nightly". Each run is short-lived, which is why
Prometheus cannot scrape it: by the time Prometheus comes looking, the job is gone.

Scenario 6: with EOD_PUSH_ENABLED=true, every run pushes its result to the Pushgateway, and
Prometheus scrapes the Pushgateway instead.

Settings (environment variables):
  PUSHGATEWAY_URL        default http://pushgateway:9091
  EOD_PUSH_ENABLED       true | false (default false: the "problem" state)
  EOD_FAILURE_MODE       random | always | never (default random)
  EOD_FAILURE_RATE       share of runs that fail in random mode (default 0.3)
  EOD_INTERVAL_SECONDS   seconds between runs (default 90)
"""
import logging
import os
import random
import time

from prometheus_client import CollectorRegistry, Gauge, pushadd_to_gateway

PUSHGATEWAY_URL = os.getenv("PUSHGATEWAY_URL", "http://pushgateway:9091")
PUSH_ENABLED = os.getenv("EOD_PUSH_ENABLED", "false").strip().lower() == "true"
FAILURE_MODE = os.getenv("EOD_FAILURE_MODE", "random").strip().lower()
FAILURE_RATE = float(os.getenv("EOD_FAILURE_RATE", "0.3"))
INTERVAL_SECONDS = int(os.getenv("EOD_INTERVAL_SECONDS", "90"))
JOB_NAME = "eod_reconciliation"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [eod-reconciliation] %(message)s")
log = logging.getLogger("eod")

FAILURE_REASONS = [
    "Position mismatch for 3 accounts",
    "Ledger snapshot unavailable",
    "Price file for previous close not found",
]


def should_fail() -> bool:
    if FAILURE_MODE == "always":
        return True
    if FAILURE_MODE == "never":
        return False
    return random.random() < FAILURE_RATE


def reconcile() -> int:
    """Simulates reconciling trades against positions. Returns the number of records checked."""
    duration = random.uniform(4, 12)
    time.sleep(duration)
    if should_fail():
        raise RuntimeError(random.choice(FAILURE_REASONS))
    return random.randint(8_000, 12_000)


def push_result(success: bool, started: float, records: int) -> None:
    """Push this run's metrics to the Pushgateway.

    pushadd (HTTP POST) only replaces the metrics sent in this push. So when a run fails and does
    not send eod_job_last_success_timestamp_seconds, the value from the last successful run stays
    in the Pushgateway. That is what makes a "job is stale" alert possible.
    """
    registry = CollectorRegistry()
    finished = time.time()

    Gauge("eod_job_last_run_timestamp_seconds", "When the last run finished (Unix time)",
          registry=registry).set(finished)
    Gauge("eod_job_duration_seconds", "Duration of the last run",
          registry=registry).set(finished - started)
    Gauge("eod_job_success", "1 if the last run succeeded, 0 if it failed",
          registry=registry).set(1 if success else 0)
    if success:
        Gauge("eod_job_last_success_timestamp_seconds", "When the last successful run finished (Unix time)",
              registry=registry).set(finished)
        Gauge("eod_job_records_processed", "Records reconciled by the last successful run",
              registry=registry).set(records)

    pushadd_to_gateway(PUSHGATEWAY_URL, job=JOB_NAME, registry=registry)


def run_once() -> None:
    started = time.time()
    log.info("Reconciliation run started")
    try:
        records = reconcile()
        success = True
        log.info("Reconciliation run succeeded: %d records checked in %.1f s", records, time.time() - started)
    except RuntimeError as exc:
        records = 0
        success = False
        log.error("Reconciliation run FAILED after %.1f s: %s", time.time() - started, exc)

    if PUSH_ENABLED:
        try:
            push_result(success, started, records)
            log.info("Result pushed to %s", PUSHGATEWAY_URL)
        except OSError as exc:
            log.warning("Could not push to the Pushgateway: %s", exc)
    else:
        log.info("Metrics push disabled (EOD_PUSH_ENABLED=false): nobody will know how this run went")


def main() -> None:
    log.info("Scheduler started: one run every %d s, failure mode '%s', push %s",
             INTERVAL_SECONDS, FAILURE_MODE, "enabled" if PUSH_ENABLED else "disabled")
    while True:
        run_once()
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
