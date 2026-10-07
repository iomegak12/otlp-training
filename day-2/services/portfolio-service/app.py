"""portfolio-service: answers "what does this customer hold?".

It calls trade-api for the account's recent trades and adds them up into positions.
There is no OpenTelemetry code here: the container starts with the zero-code launcher
(`opentelemetry-instrument python app.py`), which instruments Flask, requests and logging.

Like trade-api, it logs personal data (account number and email) on purpose (scenario 3)
and writes DEBUG logs (scenario 4).
"""
import logging
import os
from collections import defaultdict

import requests
from flask import Flask, jsonify, request

TRADE_API_URL = os.getenv("TRADE_API_URL", "http://trade-api:8080")

# Console logging. A handler is added explicitly (rather than logging.basicConfig) because the
# zero-code launcher has already attached its OpenTelemetry handler to the root logger.
_console = logging.StreamHandler()
_console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
logging.getLogger().addHandler(_console)
logging.getLogger().setLevel(logging.INFO)

log = logging.getLogger("portfolio")
log.setLevel(logging.DEBUG)  # DEBUG noise for scenario 4

app = Flask(__name__)
http = requests.Session()


@app.get("/api/portfolio/<account_number>")
def get_portfolio(account_number: str):
    email = request.args.get("email", "unknown")
    log.debug("Fetching recent trades for account %s", account_number)

    response = http.get(f"{TRADE_API_URL}/api/trades/{account_number}/recent", timeout=5)
    if response.status_code >= 500:
        log.error("trade-api failed with HTTP %s for account %s", response.status_code, account_number)
        return jsonify(error="Trade history unavailable"), 502
    response.raise_for_status()

    positions = defaultdict(int)
    for trade in response.json():
        quantity = trade["quantity"] if trade["side"] == "BUY" else -trade["quantity"]
        positions[trade["symbol"]] += quantity

    log.debug("Computed %d positions for account %s", len(positions), account_number)
    log.info("Portfolio served for account %s (customer %s)", account_number, email)
    return jsonify(accountNumber=account_number, positions=positions)


@app.get("/health")
def health():
    return "ok"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, threaded=True, debug=False, use_reloader=False)
