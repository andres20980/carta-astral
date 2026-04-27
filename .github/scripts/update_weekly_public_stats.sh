#!/usr/bin/env bash
set -euo pipefail

pip -q install google-auth 2>/dev/null
TOKEN=$(python3 -c "
import google.auth, google.auth.transport.requests
creds, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/analytics.readonly'])
creds.refresh(google.auth.transport.requests.Request())
print(creds.token)
" 2>/dev/null || echo "")

TOTAL_CHARTS=0
TOTAL_VISITORS=0
if [ -n "$TOKEN" ]; then
  API="https://analyticsdata.googleapis.com/v1beta/${GA4_PROPERTY}:runReport"
  AUTH=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

  TOTAL_CHARTS=$(curl -sS --fail-with-body --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 30 "${AUTH[@]}" -X POST \
    -d '{
      "dateRanges": [{"startDate": "2026-01-01", "endDate": "today"}],
      "metrics": [{"name": "eventCount"}],
      "dimensionFilter": {
        "filter": {"fieldName": "eventName", "stringFilter": {"value": "chart_calculated"}}
      }
    }' "$API" \
    | python3 -c "import sys,json;r=json.load(sys.stdin);print(r.get('rows',[{}])[0].get('metricValues',[{}])[0].get('value','0'))" 2>/dev/null || echo "0")

  TOTAL_VISITORS=$(curl -sS --fail-with-body --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 30 "${AUTH[@]}" -X POST \
    -d '{
      "dateRanges": [{"startDate": "2026-01-01", "endDate": "today"}],
      "metrics": [{"name": "totalUsers"}]
    }' "$API" \
    | python3 -c "import sys,json;r=json.load(sys.stdin);print(r.get('rows',[{}])[0].get('metricValues',[{}])[0].get('value','0'))" 2>/dev/null || echo "0")
fi

python3 -c "
import json
from datetime import datetime, UTC
stats = {
  'charts_calculated': int('${TOTAL_CHARTS}' or 0),
  'visitors': int('${TOTAL_VISITORS}' or 0),
  'scope': 'GA4 totals since 2026-01-01; may include historical technical/internal traffic before opt-out activation',
  'updated': datetime.now(UTC).strftime('%Y-%m-%dT%H:%MZ')
}
with open('sites/carta-astral/public/stats.json','w') as f:
  json.dump(stats, f)
"
python3 .github/scripts/update_ops_status.py

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add docs/GROWTH_MILESTONES.json docs/OPS_STATUS.md sites/carta-astral/public/stats.json sites/*/docs/SEO_GSC_QUERIES.json sites/*/docs/SEO_GA4_PAGES.json sites/*/docs/SEO_TEMPLATE_FAMILIES.json

if git diff --cached --quiet; then
  echo "No weekly public stats changes to commit."
else
  git commit -m "chore: update growth milestone + public stats"
  git push
fi
