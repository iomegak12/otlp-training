"""Steady TradeNova traffic for the Day 3 lab.

  - LOADGEN_RPS requests per second (default 5): about 60% portfolio look-ups, 40% new trades
  - every second, a GET /health on trade-api and on portfolio-service

Customer data is invented. The e-mails and card numbers are the personal data that the
attribute allowlist removes in Lab 4. The heavy "market open" burst in Lab 1 uses telemetrygen.
"""
import os
import random
import threading
import time

import requests

TRADE_API_URL = os.getenv("TRADE_API_URL", "http://trade-api:8080")
PORTFOLIO_URL = os.getenv("PORTFOLIO_URL", "http://portfolio-service:8000")
RPS = float(os.getenv("LOADGEN_RPS", "5"))

SYMBOLS = ["TNVA", "ACME", "ORBT", "QNTM", "ZEPH"]
FIRST_NAMES = ["asha", "ben", "chen", "diego", "emma", "farah", "george", "hana", "ivan", "julia"]
LAST_NAMES = ["iyer", "smith", "wong", "garcia", "brown", "khan", "miller", "sato", "petrov", "rossi"]


def customer(n: int) -> dict:
    first = FIRST_NAMES[n % len(FIRST_NAMES)]
    last = LAST_NAMES[(n // len(FIRST_NAMES)) % len(LAST_NAMES)]
    return {
        "accountNumber": f"ACC-{10_000_000 + n}",
        "customerEmail": f"{first}.{last}{n}@example.com",
    }


def card_number() -> str:
    """A made-up 16-digit card number in 4-4-4-4 format (not a real card)."""
    groups = ["4" + "".join(random.choices("0123456789", k=3))]
    groups += ["".join(random.choices("0123456789", k=4)) for _ in range(3)]
    return "-".join(groups)


def wait_for(url: str) -> None:
    while True:
        try:
            requests.get(url, timeout=2)
            return
        except requests.RequestException:
            print(f"Waiting for {url} ...", flush=True)
            time.sleep(3)


def health_checks() -> None:
    session = requests.Session()
    while True:
        for url in (f"{TRADE_API_URL}/health", f"{PORTFOLIO_URL}/health"):
            try:
                session.get(url, timeout=2)
            except requests.RequestException:
                pass
        time.sleep(1)


def traffic() -> None:
    session = requests.Session()
    sent = 0
    while True:
        who = customer(random.randint(0, 4_999))
        try:
            if random.random() < 0.6:
                session.get(f"{PORTFOLIO_URL}/api/portfolio/{who['accountNumber']}",
                            params={"email": who["customerEmail"]}, timeout=10)
            else:
                body = {**who,
                        "symbol": random.choice(SYMBOLS),
                        "side": random.choice(["BUY", "SELL"]),
                        "quantity": random.randint(1, 200)}
                if random.random() < 0.3:
                    body["fundingCardNumber"] = card_number()
                session.post(f"{TRADE_API_URL}/api/trades", json=body, timeout=10)
            sent += 1
            if sent % 500 == 0:
                print(f"{sent} requests sent", flush=True)
        except requests.RequestException as exc:
            print(f"Request failed: {exc}", flush=True)
            time.sleep(1)
        time.sleep(random.expovariate(RPS))


if __name__ == "__main__":
    wait_for(f"{TRADE_API_URL}/health")
    wait_for(f"{PORTFOLIO_URL}/health")
    print(f"Sending about {RPS} requests per second, plus health checks every second", flush=True)
    threading.Thread(target=health_checks, daemon=True).start()
    traffic()
