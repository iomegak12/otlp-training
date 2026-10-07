"""Lab C: see the difference between cumulative and delta temporality.

Run inside the settlement container:
    docker compose exec settlement-service python temporality_demo.py

The same counter is incremented by 5 three times and collected after each increment,
once with cumulative temporality and once with delta temporality.
"""
from opentelemetry.sdk.metrics import Counter, MeterProvider
from opentelemetry.sdk.metrics.export import AggregationTemporality, InMemoryMetricReader


def run(temporality: AggregationTemporality) -> None:
    reader = InMemoryMetricReader(preferred_temporality={Counter: temporality})
    provider = MeterProvider(metric_readers=[reader])
    orders = provider.get_meter("temporality-demo").create_counter("demo.orders.placed", unit="{order}")

    print(f"\n{temporality.name.capitalize()} temporality")
    for collection in range(1, 4):
        orders.add(5, {"side": "BUY"})
        data = reader.get_metrics_data()
        point = data.resource_metrics[0].scope_metrics[0].metrics[0].data.data_points[0]
        print(f"  collection {collection}: value={point.value:<3} "
              f"start={point.start_time_unix_nano} time={point.time_unix_nano}")
    provider.shutdown()


if __name__ == "__main__":
    print("Each collection adds 5 orders.")
    run(AggregationTemporality.CUMULATIVE)
    run(AggregationTemporality.DELTA)
    print("\nCumulative: the value is the running total and the start time never changes.")
    print("Delta: the value is only what happened since the last collection, and the start time moves.")
