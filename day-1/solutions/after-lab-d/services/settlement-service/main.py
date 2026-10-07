"""settlement-service (solution after Lab D): consumes accepted orders from Kafka and records the trades in PostgreSQL.

For each order on the trade.orders topic it:
  1. fetches the settlement price from quote-service (HTTP),
  2. inserts the trade into PostgreSQL,
  3. notifies the customer on a background worker thread.

This service is instrumented manually (see telemetry.py). The three context propagation
bugs are fixed; each fix is marked "LAB D".
"""
import contextvars
import json
import logging
import os
import random
import signal
import time
from concurrent.futures import ThreadPoolExecutor

import psycopg
import requests
from confluent_kafka import Consumer, KafkaError
from confluent_kafka.admin import AdminClient, NewTopic
from opentelemetry import baggage, context, metrics, trace
from opentelemetry.propagate import extract, inject
from opentelemetry.trace import SpanKind, Status, StatusCode

import telemetry

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
QUOTE_SERVICE_URL = os.getenv("QUOTE_SERVICE_URL", "http://quote-service:8000")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://tradenova:tradenova@postgres:5432/tradenova")
TOPIC = "trade.orders"

INSERT_SQL = (
    "INSERT INTO trades (order_id, account_id, symbol, side, quantity, order_price, settlement_price) "
    "VALUES (%s, %s, %s, %s, %s, %s, %s) ON CONFLICT (order_id) DO NOTHING"
)

telemetry.setup()

log = logging.getLogger("settlement-service")
tracer = trace.get_tracer("com.tradenova.settlement")
meter = metrics.get_meter("com.tradenova.settlement")

settlement_duration = meter.create_histogram(
    "tradenova.settlement.duration",
    unit="s",
    description="Time to settle one trade, from message received to customer notification queued",
)
trades_settled = meter.create_counter(
    "tradenova.trades.settled",
    unit="{trade}",
    description="Trades processed by settlement-service, by outcome",
)

notification_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="notify")


# --------------------------------------------------------------------------- downstream calls

def fetch_settlement_price(symbol: str) -> float:
    with tracer.start_as_current_span("GET", kind=SpanKind.CLIENT) as span:
        url = f"{QUOTE_SERVICE_URL}/api/quotes/{symbol}"
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("url.full", url)
        span.set_attribute("server.address", "quote-service")

        headers = {}
        # LAB D, fix 2: write the current context into the outgoing request (traceparent and
        # baggage headers), so quote-service continues this trace instead of starting a new one.
        inject(headers)
        response = requests.get(url, headers=headers, timeout=3)

        span.set_attribute("http.response.status_code", response.status_code)
        if response.status_code >= 400:
            span.set_status(Status(StatusCode.ERROR))
        response.raise_for_status()
        return response.json()["price"]


def record_trade(conn: psycopg.Connection, order: dict, settlement_price: float) -> None:
    with tracer.start_as_current_span("INSERT trades", kind=SpanKind.CLIENT) as span:
        # LAB E: these are the old (pre-stable) database semantic convention names.
        span.set_attribute("db.system", "postgresql")
        span.set_attribute("db.name", "tradenova")
        span.set_attribute("db.operation", "INSERT")
        span.set_attribute("db.statement", INSERT_SQL)

        with conn.cursor() as cur:
            cur.execute(INSERT_SQL, (
                order["orderId"], order["accountId"], order["symbol"], order["side"],
                order["quantity"], order["price"], settlement_price,
            ))
        conn.commit()


def notify_customer(order: dict) -> None:
    """Runs on a worker thread from notification_pool."""
    with tracer.start_as_current_span("notify customer") as span:
        span.set_attribute("tradenova.order.id", order["orderId"])
        time.sleep(random.uniform(0.01, 0.05))  # simulated call to the notification gateway
        log.info("Customer notified for order %s", order["orderId"])


# --------------------------------------------------------------------------- message handling

def process(message, conn: psycopg.Connection) -> None:
    """Called once for every Kafka message."""
    order = json.loads(message.value())

    # LAB D, fix 1: extract -> attach -> work -> detach.
    # extract() reads traceparent and baggage from the Kafka message headers. attach() makes that
    # context current, so the consumer span becomes its child AND the baggage travels on to every
    # outgoing call. (Passing context= to start_as_current_span alone would keep the parent span
    # but lose the baggage.) detach() restores the previous context when the message is done.
    carrier = {key: value.decode("utf-8") for key, value in (message.headers() or []) if value is not None}
    token = context.attach(extract(carrier))
    try:
        settle(message, order, conn)
    finally:
        context.detach(token)


def settle(message, order: dict, conn: psycopg.Connection) -> None:
    started = time.perf_counter()

    with tracer.start_as_current_span("trade.orders process", kind=SpanKind.CONSUMER) as span:
        span.set_attribute("messaging.system", "kafka")
        span.set_attribute("messaging.destination.name", message.topic())
        span.set_attribute("messaging.operation.type", "process")
        span.set_attribute("tradenova.order.id", order["orderId"])
        span.set_attribute("tradenova.order.symbol", order["symbol"])

        # LAB D, baggage: the channel was set by the client that placed the order and carried
        # through order-service and Kafka. Baggage is not added to spans automatically.
        channel = baggage.get_baggage("tradenova.channel")
        if channel is not None:
            span.set_attribute("tradenova.channel", str(channel))

        try:
            price = fetch_settlement_price(order["symbol"])
            record_trade(conn, order, price)
            outcome = "settled"
            log.info("Trade %s settled: %s %s x %s at %.2f",
                     order["orderId"], order["side"], order["symbol"], order["quantity"], price)
        except Exception as exc:  # noqa: BLE001 - every failure is recorded on the span
            conn.rollback()
            outcome = "failed"
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, str(exc)))
            log.error("Settlement failed for order %s: %s", order["orderId"], exc)

        # LAB D, fix 3: a ThreadPoolExecutor does not copy contextvars to the worker thread.
        # Run the task inside a copy of the current context so "notify customer" keeps its parent.
        notification_pool.submit(contextvars.copy_context().run, notify_customer, order)

        attributes = {"symbol": order["symbol"], "side": order["side"], "outcome": outcome}
        # LAB C: account_id gives this histogram one series per account.
        settlement_duration.record(time.perf_counter() - started,
                                   {**attributes, "account_id": order["accountId"]})
        trades_settled.add(1, attributes)


# --------------------------------------------------------------------------- startup

def ensure_topic() -> None:
    """Create the topic up front so the consumer does not wait for a metadata refresh."""
    admin = AdminClient({"bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS})
    futures = admin.create_topics([NewTopic(TOPIC, num_partitions=3, replication_factor=1)])
    for future in futures.values():
        try:
            future.result()
        except Exception as exc:  # noqa: BLE001
            if "TOPIC_ALREADY_EXISTS" not in str(exc):
                log.warning("Could not create topic %s: %s", TOPIC, exc)


def connect_db() -> psycopg.Connection:
    for attempt in range(1, 31):
        try:
            return psycopg.connect(DATABASE_URL)
        except psycopg.OperationalError as exc:
            log.info("Waiting for PostgreSQL (attempt %d): %s", attempt, exc)
            time.sleep(2)
    raise SystemExit("PostgreSQL is not reachable")


def main() -> None:
    running = True

    def stop(*_):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    ensure_topic()
    conn = connect_db()
    consumer = Consumer({
        "bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS,
        "group.id": "settlement-service",
        "auto.offset.reset": "latest",
        "topic.metadata.refresh.interval.ms": 10_000,
    })
    consumer.subscribe([TOPIC])
    log.info("settlement-service consuming from %s", TOPIC)

    try:
        while running:
            message = consumer.poll(1.0)
            if message is None:
                continue
            if message.error():
                if message.error().code() != KafkaError._PARTITION_EOF:
                    log.warning("Kafka error: %s", message.error())
                continue
            process(message, conn)
    finally:
        consumer.close()
        conn.close()
        notification_pool.shutdown(wait=True)
        telemetry.shutdown()


if __name__ == "__main__":
    main()
