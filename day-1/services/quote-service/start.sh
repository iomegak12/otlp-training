#!/bin/sh
# Starts quote-service with or without OpenTelemetry zero-code instrumentation.
# Lab B: set QUOTE_ZERO_CODE=true in config/quote-service.env.
if [ "$QUOTE_ZERO_CODE" = "true" ]; then
  echo "Starting with OpenTelemetry zero-code instrumentation"
  exec opentelemetry-instrument python app.py
fi
echo "Starting without instrumentation"
exec python app.py
