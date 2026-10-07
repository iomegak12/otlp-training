"""Sends a steady stream of TradeNova orders to order-service.

Mix of traffic:
  - about 91% normal orders
  - about 5% unknown ticker symbols (order-service answers 400)
  - about 4% oversized orders that usually fail the risk check (422)

Every request carries W3C baggage with the channel the order came from
(web, mobile or api). Lab D follows this value all the way to settlement-service.
The load generator itself is not instrumented, so order-service starts each trace.
"""
import os
import random
import time

import requests

ORDER_SERVICE_URL = os.getenv("ORDER_SERVICE_URL", "http://order-service:8080")
ORDERS_PER_SECOND = float(os.getenv("ORDERS_PER_SECOND", "4"))

SYMBOLS = ["TNVA", "ACME", "ORBT", "QNTM", "ZEPH"]
CHANNELS = ["web", "mobile", "api"]


def next_order() -> dict:
    roll = random.random()
    symbol = random.choice(SYMBOLS)
    quantity = random.randint(1, 200)
    if roll < 0.05:
        symbol = random.choice(["XXXX", "FAKE", "NOPE"])
    elif roll < 0.09:
        quantity = random.randint(2_000, 8_000)
    return {
        # 5,000 accounts: enough to show what a high-cardinality metric attribute costs (Lab C).
        "accountId": f"ACC-{random.randint(10_000, 14_999)}",
        "symbol": symbol,
        "side": random.choice(["BUY", "SELL"]),
        "quantity": quantity,
    }


def wait_for_order_service() -> None:
    while True:
        try:
            requests.get(f"{ORDER_SERVICE_URL}/actuator/health", timeout=2)
            return
        except requests.RequestException:
            print("Waiting for order-service ...", flush=True)
            time.sleep(3)


def main() -> None:
    wait_for_order_service()
    print(f"Sending about {ORDERS_PER_SECOND} orders per second to {ORDER_SERVICE_URL}", flush=True)
    session = requests.Session()
    sent = 0
    while True:
        headers = {"baggage": f"tradenova.channel={random.choice(CHANNELS)}"}
        try:
            response = session.post(f"{ORDER_SERVICE_URL}/api/orders", json=next_order(),
                                    headers=headers, timeout=5)
            sent += 1
            if sent % 100 == 0:
                print(f"{sent} orders sent (last status {response.status_code})", flush=True)
        except requests.RequestException as exc:
            print(f"Request failed: {exc}", flush=True)
            time.sleep(1)
        time.sleep(random.expovariate(ORDERS_PER_SECOND))


if __name__ == "__main__":
    main()
