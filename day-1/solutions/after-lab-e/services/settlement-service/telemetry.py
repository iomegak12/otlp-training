"""OpenTelemetry SDK setup for settlement-service (manual instrumentation).

Everything the Java agent and the Python zero-code launcher do for the other services
is done here by hand: create the providers, attach processors and exporters, register them.

The OTLP exporters read OTEL_EXPORTER_OTLP_ENDPOINT from the environment
(config/settlement-service.env) and add /v1/traces, /v1/metrics and /v1/logs.
"""
import logging

from opentelemetry import metrics, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.logging.handler import LoggingHandler
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.metrics.view import ExplicitBucketHistogramAggregation, View
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

_providers = []


def setup() -> None:
    # LAB E: no hard-coded attributes. Resource.create() reads OTEL_SERVICE_NAME and
    # OTEL_RESOURCE_ATTRIBUTES (config/settlement-service.env), so every service is named and
    # labelled the same way, from configuration.
    resource = Resource.create()

    # ---- traces
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    # ---- metrics (exported every 10 seconds so changes show up quickly in the labs)
    reader = PeriodicExportingMetricReader(OTLPMetricExporter(), export_interval_millis=10_000)
    # LAB C, step 4: keep only low-cardinality attributes (account_id is dropped) and use
    # bucket boundaries in seconds. The default boundaries (0, 5, 10, 25 ... 10000) suit
    # milliseconds and would put every settlement in the same bucket.
    settlement_duration_view = View(
        instrument_name="tradenova.settlement.duration",
        attribute_keys={"symbol", "side", "outcome"},
        aggregation=ExplicitBucketHistogramAggregation(
            boundaries=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
        ),
    )
    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[reader],
        views=[settlement_duration_view],
    )
    metrics.set_meter_provider(meter_provider)

    # ---- logs
    # LAB C, step 5: export log records over OTLP. The handler adds the trace_id and span_id
    # of the current span to every record, which is what links logs to traces.
    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
    set_logger_provider(logger_provider)
    logging.getLogger().addHandler(LoggingHandler(level=logging.INFO, logger_provider=logger_provider))

    _setup_console_logging()

    _providers.extend([tracer_provider, meter_provider, logger_provider])


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
