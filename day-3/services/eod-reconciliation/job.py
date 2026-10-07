"""eod-reconciliation: TradeNova's end-of-day reconciliation, run as a Kubernetes CronJob.

Each run checks a sample of customer portfolios through portfolio-service, logs the result
and exits. There is no OpenTelemetry code here: the Operator injects Python auto-instrumentation
into the CronJob's pods, so every run becomes a trace (job -> portfolio-service -> trade-api)
and its log lines are exported with that trace ID. The SDK flushes its data when the process exits.

Settings (environment variables):
  PORTFOLIO_URL       default http://portfolio-service:8000
  EOD_SAMPLE_SIZE     portfolios checked per run (default 20)
  EOD_FAILURE_RATE    share of runs that fail (default 0.2)
"""
import logging
import os
import random
import sys
import time

import requests

PORTFOLIO_URL = os.getenv("PORTFOLIO_URL", "http://portfolio-service:8000")
SAMPLE_SIZE = int(os.getenv("EOD_SAMPLE_SIZE", "20"))
FAILURE_RATE = float(os.getenv("EOD_FAILURE_RATE", "0.2"))

_console = logging.StreamHandler()
_console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [eod-reconciliation] %(message)s"))
logging.getLogger().addHandler(_console)
logging.getLogger().setLevel(logging.INFO)
log = logging.getLogger("eod")


def main() -> int:
    started = time.time()
    log.info("Reconciliation run started: checking %d portfolios", SAMPLE_SIZE)
    checked = errors = 0
    session = requests.Session()
    for _ in range(SAMPLE_SIZE):
        account = f"ACC-{10_000_000 + random.randint(0, 4_999)}"
        try:
            response = session.get(f"{PORTFOLIO_URL}/api/portfolio/{account}", timeout=5)
            checked += 1
            if response.status_code >= 500:
                errors += 1
        except requests.RequestException as exc:
            errors += 1
            log.warning("Portfolio check failed for %s: %s", account, exc)

    if random.random() < FAILURE_RATE:
        log.error("Reconciliation run FAILED after %.1f s: position mismatch for 3 accounts", time.time() - started)
        return 1
    log.info("Reconciliation run succeeded: %d portfolios checked, %d errors, %.1f s",
             checked, errors, time.time() - started)
    return 0


if __name__ == "__main__":
    sys.exit(main())
