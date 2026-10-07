#!/usr/bin/env bash
# Lab 4: who can send telemetry to the agent? Four clients knock on the door (OTLP/HTTP, port 4318):
#   1. plain HTTP, no certificate, no token          (anyone on the network)
#   2. HTTPS, no client certificate                  (knows the CA, has no identity)
#   3. HTTPS + client certificate, no token          (stolen certificate, no secret)
#   4. HTTPS + client certificate + token            (a real TradeNova workload)
# Run it before Lab 4 (everything gets in) and after Lab 4 (only number 4 gets in).
source "$(dirname "$0")/../../scripts/common.sh"
ensure_test_client
AGENT=otel-agent-collector.observability.svc.cluster.local:4318
BODY='{"resourceSpans":[]}'
TOKEN=$(kubectl get secret otel-ingest-token -n tradenova -o jsonpath='{.data.token}' | base64 -d)

# Prints ACCEPTED or REJECTED with the reason. $1 = label, $2 = "expect-accept" or "expect-reject".
knock() {
  local label="$1" expect="$2"; shift 2
  local code reason colour
  code=$(in_test_client curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
         -H 'Content-Type: application/json' -d "$BODY" "$@" 2> /dev/null || true)
  code="${code:0:3}"
  case "$code" in
    200) reason="HTTP 200" ;;
    400) reason="HTTP 400: plain HTTP sent to an HTTPS port" ;;
    401) reason="HTTP 401: no valid token" ;;
    000|"") reason="no TLS session: no client certificate, or the agent does not speak HTTPS" ;;
    *)   reason="HTTP $code" ;;
  esac
  if [[ "$code" == 200 ]]; then verdict=ACCEPTED; else verdict=REJECTED; fi
  if { [[ "$verdict" == ACCEPTED && "$expect" == expect-accept ]] || [[ "$verdict" == REJECTED && "$expect" == expect-reject ]]; }; then
    colour='1;32'; else colour='1;31'; fi
  printf '  %-44s \033[%sm%s\033[0m  (%s)\n' "$label" "$colour" "$verdict" "$reason"
}

step "Knocking on the agent's door ($AGENT)"
knock "1. plain HTTP, no certificate, no token" expect-reject "http://$AGENT/v1/traces"
knock "2. HTTPS, no client certificate" expect-reject --cacert /certs/ca.crt "https://$AGENT/v1/traces"
knock "3. HTTPS + client certificate, no token" expect-reject \
      --cacert /certs/ca.crt --cert /certs/tls.crt --key /certs/tls.key "https://$AGENT/v1/traces"
knock "4. certificate + token (a TradeNova app)" expect-accept \
      --cacert /certs/ca.crt --cert /certs/tls.crt --key /certs/tls.key \
      -H "x-tradenova-token: $TOKEN" "https://$AGENT/v1/traces"
echo
echo "Green = what we want, red = a problem."
echo "Before Lab 4: number 1 gets in (anyone can send), and 2-4 fail because the agent does not speak HTTPS yet."
echo "After Lab 4:  only number 4 gets in."
