"""quote-service: returns the current (simulated) price of a TradeNova ticker symbol.

This file contains no OpenTelemetry code at all. In Lab B it is instrumented
from the outside with the zero-code launcher: `opentelemetry-instrument python app.py`.
"""
import logging
import random
import threading
import time
from datetime import datetime, timezone

from flask import Flask, jsonify

# Console logging. A handler is added explicitly (rather than logging.basicConfig) because the
# zero-code launcher may already have attached its own OpenTelemetry handler to the root logger.
_console = logging.StreamHandler()
_console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
logging.getLogger().addHandler(_console)
logging.getLogger().setLevel(logging.INFO)
log = logging.getLogger("quote-service")

app = Flask(__name__)

# Invented tickers, so nobody mistakes this for real market data.
_prices = {"TNVA": 182.40, "ACME": 64.15, "ORBT": 27.80, "QNTM": 245.90, "ZEPH": 118.35}
_lock = threading.Lock()


def _next_price(symbol: str) -> float:
    """Random walk of up to +/-0.5% per request."""
    with _lock:
        price = _prices[symbol] * (1 + random.uniform(-0.005, 0.005))
        _prices[symbol] = price
        return round(price, 2)


@app.get("/api/quotes/<symbol>")
def get_quote(symbol: str):
    symbol = symbol.upper()
    if symbol not in _prices:
        log.warning("Quote requested for unknown symbol %s", symbol)
        return jsonify(error=f"Unknown symbol {symbol}"), 404

    # Normal latency is 5-30 ms; about 2% of requests hit a slow market-data feed.
    if random.random() < 0.02:
        log.warning("Slow market-data feed for %s", symbol)
        time.sleep(random.uniform(0.6, 0.9))
    else:
        time.sleep(random.uniform(0.005, 0.03))

    price = _next_price(symbol)
    log.info("Quote %s %.2f", symbol, price)
    return jsonify(symbol=symbol, price=price, currency="USD",
                   ts=datetime.now(timezone.utc).isoformat())


@app.get("/health")
def health():
    return "ok"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, threaded=True, debug=False, use_reloader=False)
