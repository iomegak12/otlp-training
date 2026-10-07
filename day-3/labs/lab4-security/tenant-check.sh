#!/usr/bin/env bash
# Lab 4: which services does each tenant see? Asks Loki and Tempo directly, once per tenant
# (X-Scope-OrgID header), for the service names they hold in the last hour.
source "$(dirname "$0")/../../scripts/common.sh"
ensure_test_client
for tenant in tradenova-shared trading wealth; do
  step "Tenant: $tenant"
  printf '  Loki : '
  in_test_client curl -s --max-time 10 -H "X-Scope-OrgID: $tenant" \
    "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/label/service_name/values" \
    | grep -o '"data":\[[^]]*\]' || echo "(nothing)"
  printf '  Tempo: '
  in_test_client curl -s --max-time 10 -H "X-Scope-OrgID: $tenant" \
    "http://tempo.monitoring.svc.cluster.local:3200/api/search/tag/service.name/values" \
    | grep -o '"tagValues":\[[^]]*\]' || echo "(nothing)"
done
echo
echo "Before Lab 4 everything is in tradenova-shared. After: trading and wealth only see their own services."
echo "(tradenova-shared keeps the data from before Lab 4, plus anything without a team label.)"
