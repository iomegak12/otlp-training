"""OpenTelemetry SDK setup for settlement-service (manual instrumentation).

Everything the Java agent and the Python zero-code launcher do for the other services
is done here by hand: create the providers, attach processors and exporters, register them.

The OTLP exporters read OTEL_EXPORTER_OTLP_ENDPOINT from the environment
(config/settlement-service.env) and add /v1/traces, /v1/metrics and /v1/logs.
"""
import logging

from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

_providers = []


def setup() -> None:
    # LAB E: the service name is hard-coded, does not follow the naming standard, and
    # overrides anything set in OTEL_SERVICE_NAME or OTEL_RESOURCE_ATTRIBUTES.
    resource = Resource.create({"service.name": "settlement"})

    # ---- traces
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    # ---- metrics (exported every 10 seconds so changes show up quickly in the labs)
    reader = PeriodicExportingMetricReader(OTLPMetricExporter(), export_interval_millis=10_000)
    # LAB C, step 4: tradenova.settlement.duration records account_id, which creates one
    # series per account. Add a View here that keeps only low-cardinality attributes and
    # sets bucket boundaries that suit durations measured in seconds.
    meter_provider = MeterProvider(resource=resource, metric_readers=[reader])
    metrics.set_meter_provider(meter_provider)

    # ---- logs
    # LAB C, step 5: logs only go to the console. Add a LoggerProvider and a handler so
    # log records are exported over OTLP with the trace_id and span_id of the current span.
    _setup_console_logging()

    _providers.extend([tracer_provider, meter_provider])


def _setup_console_logging() -> None:
    console = logging.StreamHandler()
    console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
    root = logging.getLogger()
    root.addHandler(console)
    root.setLevel(logging.INFO)


def shutdown() -> None:
    """Flush buffered telemetry before the process exits."""
    for provider in _providers:
        provider.shutdown()
