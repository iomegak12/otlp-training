#!/usr/bin/env python3
"""Lab A: speak OTLP by hand.

Sends one trace (two spans), one metric and one log record to the Collector as OTLP/JSON
over HTTP, using only the Python standard library. No OpenTelemetry SDK is involved.

    python3 send_otlp.py                 # send all three signals
    python3 send_otlp.py --show          # also print the JSON payloads
    python3 send_otlp.py --endpoint http://localhost:4318
"""
import argparse
import json
import os
import time
import urllib.request

parser = argparse.ArgumentParser(description="Send OTLP/JSON traces, metrics and logs to a Collector")
parser.add_argument("--endpoint", default="http://localhost:4318", help="OTLP/HTTP base URL")
parser.add_argument("--show", action="store_true", help="print each JSON payload before sending it")
args = parser.parse_args()

# Every batch starts with a resource (who sent it) and an instrumentation scope (which library).
RESOURCE = {"attributes": [
    {"key": "service.name", "value": {"stringValue": "lab-a-cli"}},
    {"key": "service.namespace", "value": {"stringValue": "tradenova"}},
    {"key": "deployment.environment.name", "value": {"stringValue": "training"}},
]}
SCOPE = {"name": "lab-a-handwritten", "version": "1.0.0"}

now = time.time_ns()
trace_id = os.urandom(16).hex()        # 32 hex characters
root_span_id = os.urandom(8).hex()     # 16 hex characters
child_span_id = os.urandom(8).hex()

traces = {"resourceSpans": [{
    "resource": RESOURCE,
    "scopeSpans": [{
        "scope": SCOPE,
        "spans": [
            {
                "traceId": trace_id,
                "spanId": root_span_id,
                "name": "POST /api/orders",
                "kind": 2,  # 1 INTERNAL, 2 SERVER, 3 CLIENT, 4 PRODUCER, 5 CONSUMER
                "startTimeUnixNano": str(now - 120_000_000),
                "endTimeUnixNano": str(now),
                "attributes": [
                    {"key": "http.request.method", "value": {"stringValue": "POST"}},
                    {"key": "http.route", "value": {"stringValue": "/api/orders"}},
                    {"key": "http.response.status_code", "value": {"intValue": "202"}},
                ],
                "status": {"code": 0},  # 0 UNSET, 1 OK, 2 ERROR
            },
            {
                "traceId": trace_id,
                "spanId": child_span_id,
                "parentSpanId": root_span_id,
                "name": "risk.check",
                "kind": 1,
                "startTimeUnixNano": str(now - 90_000_000),
                "endTimeUnixNano": str(now - 70_000_000),
                "attributes": [
                    {"key": "tradenova.order.symbol", "value": {"stringValue": "TNVA"}},
                    {"key": "tradenova.order.value", "value": {"doubleValue": 18240.0}},
                    {"key": "tradenova.risk.decision", "value": {"stringValue": "approved"}},
                ],
                "events": [{
                    "timeUnixNano": str(now - 80_000_000),
                    "name": "limit.evaluated",
                    "attributes": [{"key": "tradenova.risk.limit", "value": {"doubleValue": 250000.0}}],
                }],
                "status": {"code": 0},
            },
        ],
    }],
}]}

metrics = {"resourceMetrics": [{
    "resource": RESOURCE,
    "scopeMetrics": [{
        "scope": SCOPE,
        "metrics": [{
            "name": "lab.orders.placed",
            "unit": "{order}",
            "description": "Orders placed, sent by hand in Lab A",
            "sum": {
                "aggregationTemporality": 2,  # 1 DELTA, 2 CUMULATIVE
                "isMonotonic": True,
                "dataPoints": [{
                    "startTimeUnixNano": str(now - 60_000_000_000),
                    "timeUnixNano": str(now),
                    "asInt": "42",
                    "attributes": [{"key": "side", "value": {"stringValue": "BUY"}}],
                }],
            },
        }],
    }],
}]}

logs = {"resourceLogs": [{
    "resource": RESOURCE,
    "scopeLogs": [{
        "scope": SCOPE,
        "logRecords": [{
            "timeUnixNano": str(now - 75_000_000),
            "observedTimeUnixNano": str(now),
            "severityNumber": 9,  # 9 = INFO
            "severityText": "INFO",
            "body": {"stringValue": "Order accepted: BUY TNVA x 100"},
            "attributes": [{"key": "tradenova.order.symbol", "value": {"stringValue": "TNVA"}}],
            # These two fields are what links a log record to its trace.
            "traceId": trace_id,
            "spanId": child_span_id,
        }],
    }],
}]}


def send(path: str, payload: dict) -> None:
    body = json.dumps(payload).encode()
    if args.show:
        print(f"\n--- POST {args.endpoint}{path}\n{json.dumps(payload, indent=2)}")
    request = urllib.request.Request(f"{args.endpoint}{path}", data=body, method="POST",
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as response:
        print(f"{path:<12} -> HTTP {response.status} {response.read().decode() or '{}'}")


send("/v1/traces", traces)
send("/v1/metrics", metrics)
send("/v1/logs", logs)
print(f"\ntrace_id = {trace_id}")
print("Find it in Jaeger: http://localhost:16686/trace/" + trace_id)
