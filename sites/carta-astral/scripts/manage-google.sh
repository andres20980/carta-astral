#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../../../shared/config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)/config.sh"

# ── Config ───────────────────────────────────────────────────────────
GA4_PROPERTY="properties/531527723"
GA4_STREAM="properties/531527723/dataStreams/14325968472"
ADSENSE_ACCOUNT="accounts/pub-9368517395014039"
CURRENT_SITE_KEY="${SITE_KEY:-carta-astral}"
DOMAIN=""
SITE_URL=""
SITE_URL_ENC=""
SITEMAP_URL=""
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

set_current_site() {
  local requested="${1:-carta-astral}"
  if [[ -n "${DOMAINS[$requested]:-}" ]]; then
    CURRENT_SITE_KEY="$requested"
  elif [[ "$requested" =~ \.es$ ]]; then
    local key
    for key in "${CLUSTER_SITE_KEYS[@]}"; do
      if [[ "${DOMAINS[$key]}" == "$requested" ]]; then
        CURRENT_SITE_KEY="$key"
        break
      fi
    done
  fi

  if [[ -z "${DOMAINS[$CURRENT_SITE_KEY]:-}" ]]; then
    echo "Unknown site: $requested" >&2
    exit 1
  fi

  DOMAIN="${DOMAINS[$CURRENT_SITE_KEY]}"
  SITE_URL="$(gsc_site_url_for "$CURRENT_SITE_KEY")"
  SITE_URL_ENC="$(python3 -c "import urllib.parse;print(urllib.parse.quote('${SITE_URL}',''))")"
  SITEMAP_URL="$(sitemap_url_for "$CURRENT_SITE_KEY")"
}

_token() {
  gcloud auth application-default print-access-token
}

_oauth_token() {
  if [[ -n "${GOOGLE_OAUTH_REFRESH_TOKEN:-}" && -n "${GOOGLE_OAUTH_CLIENT_ID:-}" && -n "${GOOGLE_OAUTH_CLIENT_SECRET:-}" ]]; then
    local resp token
    resp=$(curl -sS https://oauth2.googleapis.com/token \
      -d "client_id=${GOOGLE_OAUTH_CLIENT_ID}" \
      -d "client_secret=${GOOGLE_OAUTH_CLIENT_SECRET}" \
      -d "refresh_token=${GOOGLE_OAUTH_REFRESH_TOKEN}" \
      -d "grant_type=refresh_token")
    token=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" <<< "$resp")
    if [[ -z "$token" ]]; then
      echo "Could not mint Google OAuth access token:" >&2
      python3 -m json.tool <<< "$resp" >&2 2>/dev/null || echo "$resp" >&2
      return 1
    fi
    echo "$token"
  else
    _token
  fi
}

_oauth_uses_adc() {
  [[ -z "${GOOGLE_OAUTH_REFRESH_TOKEN:-}" || -z "${GOOGLE_OAUTH_CLIENT_ID:-}" || -z "${GOOGLE_OAUTH_CLIENT_SECRET:-}" ]]
}

_adc_quota_project() {
  if [[ -n "${GOOGLE_CLOUD_QUOTA_PROJECT:-}" ]]; then
    echo "$GOOGLE_CLOUD_QUOTA_PROJECT"
    return
  fi
  gcloud auth application-default get-quota-project 2>/dev/null || true
}

_api() {
  curl -s -H "Authorization: Bearer $(_token)" "$@"
}

_api_oauth() {
  local token quota
  token="$(_oauth_token)" || return
  if _oauth_uses_adc; then
    quota="$(_adc_quota_project)"
    if [[ -n "$quota" ]]; then
      curl -sS -H "Authorization: Bearer $token" -H "X-Goog-User-Project: $quota" "$@"
      return
    fi
  fi
  curl -sS -H "Authorization: Bearer $token" "$@"
}

_ga4_admin_token() {
  if [[ -n "${GOOGLE_OAUTH_REFRESH_TOKEN:-}" && -n "${GOOGLE_OAUTH_CLIENT_ID:-}" && -n "${GOOGLE_OAUTH_CLIENT_SECRET:-}" ]]; then
    _oauth_token
  else
    _token
  fi
}

_analytics_status_local() {
  local resp
  resp=$(_api "https://analyticsadmin.googleapis.com/v1beta/${GA4_PROPERTY}" 2>/dev/null || true)
  python3 -c "
import json,sys
raw=sys.stdin.read().strip()
if not raw:
  print('No comprobado localmente: sin respuesta de Analytics Admin API; el check canónico corre en GitHub Actions')
  raise SystemExit(0)
try:
  data=json.loads(raw)
except Exception:
  print('No comprobado localmente: respuesta no JSON desde Analytics Admin API')
  raise SystemExit(0)
if data.get('name'):
  print('OK: service account / ADC con acceso a GA4')
else:
  err=data.get('error',{})
  msg=err.get('message') or 'sin detalle'
  if 'insufficient authentication scopes' in msg.lower():
    print('No comprobado localmente: ADC sin scopes de Analytics; el check canónico corre en GitHub Actions con FIREBASE_SERVICE_ACCOUNT')
  else:
    print(f'Pendiente: {msg}')
" <<< "$resp"
}

set_current_site "$CURRENT_SITE_KEY"

# ── Commands ─────────────────────────────────────────────────────────

cmd_status() {
  echo "━━━ GA4 Property ━━━"
  _api "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY" | python3 -m json.tool

  echo ""
  echo "━━━ GA4 Data Streams ━━━"
  _api "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY/dataStreams" | python3 -m json.tool

  echo ""
  echo "━━━ AdSense Sites ━━━"
  _api_oauth "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/sites" | python3 -m json.tool

  echo ""
  echo "━━━ AdSense Ad Clients ━━━"
  _api_oauth "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/adclients" | python3 -m json.tool
}

cmd_ga4_realtime() {
  echo "━━━ GA4 Realtime (last 30 min) ━━━"
  _api -X POST \
    -H "Content-Type: application/json" \
    -d '{
      "dimensions": [{"name": "unifiedScreenName"}],
      "metrics": [{"name": "activeUsers"}],
      "limit": 20
    }' \
    "https://analyticsdata.googleapis.com/v1beta/$GA4_PROPERTY:runRealtimeReport" | python3 -m json.tool
}

cmd_ga4_report() {
  local days="${1:-7}"
  echo "━━━ GA4 Report (last ${days} days) ━━━"
  _api -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"dateRanges\": [{\"startDate\": \"${days}daysAgo\", \"endDate\": \"today\"}],
      \"dimensions\": [
        {\"name\": \"date\"},
        {\"name\": \"sessionDefaultChannelGroup\"}
      ],
      \"metrics\": [
        {\"name\": \"sessions\"},
        {\"name\": \"totalUsers\"},
        {\"name\": \"screenPageViews\"},
        {\"name\": \"averageSessionDuration\"}
      ],
      \"orderBys\": [{\"dimension\": {\"dimensionName\": \"date\"}, \"desc\": true}],
      \"limit\": 50
    }" \
    "https://analyticsdata.googleapis.com/v1beta/$GA4_PROPERTY:runReport" | python3 -m json.tool
}

cmd_ga4_top_pages() {
  local days="${1:-30}"
  echo "━━━ Top Pages (last ${days} days) ━━━"
  _api -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"dateRanges\": [{\"startDate\": \"${days}daysAgo\", \"endDate\": \"today\"}],
      \"dimensions\": [{\"name\": \"pagePath\"}],
      \"metrics\": [
        {\"name\": \"screenPageViews\"},
        {\"name\": \"totalUsers\"},
        {\"name\": \"averageSessionDuration\"}
      ],
      \"orderBys\": [{\"metric\": {\"metricName\": \"screenPageViews\"}, \"desc\": true}],
      \"limit\": 20
    }" \
    "https://analyticsdata.googleapis.com/v1beta/$GA4_PROPERTY:runReport" | python3 -m json.tool
}

cmd_ga4_key_events() {
  echo "━━━ GA4 Key Events ━━━"
  _api "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY/keyEvents" | python3 -m json.tool
}

cmd_ga4_custom_dimensions() {
  python3 "${REPO_ROOT}/.github/scripts/ga4_custom_definitions.py" \
    --property "$GA4_PROPERTY" \
    --token "$(_ga4_admin_token)" \
    --manifest "${REPO_ROOT}/shared/ga4_custom_dimensions.json"
}

cmd_ga4_apply_custom_dimensions() {
  python3 "${REPO_ROOT}/.github/scripts/ga4_custom_definitions.py" \
    --property "$GA4_PROPERTY" \
    --token "$(_ga4_admin_token)" \
    --manifest "${REPO_ROOT}/shared/ga4_custom_dimensions.json" \
    --apply
}

cmd_ga4_sync_key_events() {
  python3 "${REPO_ROOT}/.github/scripts/ga4_key_events.py" \
    --property "$GA4_PROPERTY" \
    --token "$(_ga4_admin_token)" \
    --manifest "${REPO_ROOT}/shared/ga4_key_events.json" \
    --apply
}

cmd_ga4_watch_admin() {
  python3 "${REPO_ROOT}/.github/scripts/ga4_admin_watch.py" \
    --property "$GA4_PROPERTY" \
    --token "$(_ga4_admin_token)" \
    --dimensions-manifest "${REPO_ROOT}/shared/ga4_custom_dimensions.json" \
    --key-events-manifest "${REPO_ROOT}/shared/ga4_key_events.json"
}

cmd_ga4_sync_admin() {
  cmd_ga4_apply_custom_dimensions
  echo ""
  cmd_ga4_sync_key_events
}

cmd_ga4_create_key_event() {
  local event_name="${1:?Usage: $0 ga4-create-key-event <event_name>}"
  echo "Creating key event: $event_name"
  _api -X POST \
    -H "Content-Type: application/json" \
    -d "{\"eventName\": \"$event_name\"}" \
    "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY/keyEvents" | python3 -m json.tool
}

cmd_adsense_earnings() {
  local days="${1:-7}"
  local start end
  start=$(date -d "$days days ago" +%Y-%m-%d)
  end=$(date +%Y-%m-%d)
  echo "━━━ AdSense Earnings ($start → $end) ━━━"
  _api_oauth "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/reports:generate?\
dateRange=CUSTOM&\
startDate.year=$(date -d "$start" +%Y)&startDate.month=$(date -d "$start" +%-m)&startDate.day=$(date -d "$start" +%-d)&\
endDate.year=$(date -d "$end" +%Y)&endDate.month=$(date -d "$end" +%-m)&endDate.day=$(date -d "$end" +%-d)&\
metrics=ESTIMATED_EARNINGS&metrics=PAGE_VIEWS&metrics=IMPRESSIONS&metrics=CLICKS&\
dimensions=DATE&\
reportingTimeZone=ACCOUNT_TIME_ZONE" | python3 -m json.tool
}

cmd_adsense_sites() {
  echo "━━━ AdSense Sites ━━━"
  _api_oauth "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/sites" | python3 -m json.tool
}

cmd_adsense_alerts() {
  echo "━━━ AdSense Alerts ━━━"
  _api_oauth "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/alerts" | python3 -m json.tool
}

cmd_google_auth_audit() {
  local oauth_token analytics_status
  oauth_token="$(_oauth_token)"
  analytics_status="$(_analytics_status_local)"
  OAUTH_TOKEN="$oauth_token" \
  ANALYTICS_SA_STATUS="$analytics_status" \
  GOOGLE_AUTH_INCLUDE_RAW_JSON=0 \
  python3 "${REPO_ROOT}/.github/scripts/google_auth_audit.py"
}

# ── Google Search Console ────────────────────────────────────────────

cmd_gsc_sites() {
  echo "━━━ GSC Verified Sites ━━━"
  _api_oauth "https://searchconsole.googleapis.com/webmasters/v3/sites" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for s in data.get('siteEntry',[]):
  print(f\"  {s['siteUrl']:40s} level={s.get('permissionLevel','-')}\")" 2>/dev/null || echo "  (no sites or no access)"
}

cmd_gsc_submit_sitemap() {
  local sitemap="${1:-$SITEMAP_URL}"
  echo "━━━ Submit sitemap to GSC ━━━"
  echo "  Site: $SITE_URL"
  echo "  Sitemap: $sitemap"
  local resp
  resp=$(_api_oauth -X PUT -w "\n%{http_code}" \
    "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/sitemaps/$(python3 -c "import urllib.parse;print(urllib.parse.quote('$sitemap',''))")")
  local code
  code=$(echo "$resp" | tail -1)
  if [[ "$code" == "204" ]] || [[ "$code" == "200" ]]; then
    echo "  ✅ Sitemap submitted successfully"
  else
    echo "  Response (HTTP $code):"
    echo "$resp" | head -n -1 | python3 -m json.tool 2>/dev/null || echo "$resp"
    if _oauth_uses_adc && [[ -z "$(_adc_quota_project)" ]]; then
      echo ""
      echo "  Hint: ADC is being used without a quota project."
      echo "  Run: gcloud auth application-default set-quota-project <project-with-searchconsole-api>"
      echo "  Or export GOOGLE_CLOUD_QUOTA_PROJECT=<project-with-searchconsole-api>."
      echo "  Prefer GOOGLE_OAUTH_* env vars for unattended GSC automation."
    fi
    return 1
  fi
}

cmd_gsc_sitemaps() {
  echo "━━━ GSC Sitemaps ━━━"
  _api_oauth "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/sitemaps" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for s in data.get('sitemap',[]):
  print(f\"  {s['path']}\")
  print(f\"    submitted={s.get('lastSubmitted','-')}  downloaded={s.get('lastDownloaded','-')}\")
  print(f\"    pending={s.get('isPending',False)}  warnings={s.get('warnings',0)}  errors={s.get('errors',0)}\")
  for c in s.get('contents',[]):
    print(f\"    type={c['type']}  submitted={c.get('submitted',0)}  indexed={c.get('indexed',0)}\")
" 2>/dev/null || echo "  (no sitemaps found)"
}

cmd_gsc_submit_sitemaps_all() {
  local site_key failures=0
  for site_key in "${CLUSTER_SITE_KEYS[@]}"; do
    set_current_site "$site_key"
    if ! cmd_gsc_submit_sitemap; then
      failures=$((failures + 1))
    fi
    echo ""
  done
  if [[ "$failures" -gt 0 ]]; then
    echo "GSC sitemap submit failed for ${failures} site(s)" >&2
    return 1
  fi
}

cmd_gsc_inspect() {
  local url="${1:-https://${DOMAIN}/}"
  echo "━━━ URL Inspection: $url ━━━"
  _api_oauth -X POST \
    -H "Content-Type: application/json" \
    -d "{\"inspectionUrl\": \"$url\", \"siteUrl\": \"$SITE_URL\"}" \
    "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect" | python3 -c "
import sys,json
data=json.load(sys.stdin)
r=data.get('inspectionResult',{})
idx=r.get('indexStatusResult',{})
print(f\"  Verdict:        {idx.get('verdict','-')}\")
print(f\"  Coverage state: {idx.get('coverageState','-')}\")
print(f\"  Indexing state: {idx.get('indexingState','-')}\")
print(f\"  Last crawl:     {idx.get('lastCrawlTime','-')}\")
print(f\"  Crawled as:     {idx.get('crawledAs','-')}\")
print(f\"  Robots.txt:     {idx.get('robotsTxtState','-')}\")
print(f\"  Page fetch:     {idx.get('pageFetchState','-')}\")
mob=r.get('mobileUsabilityResult',{})
print(f\"  Mobile:         {mob.get('verdict','-')}\")
rich=r.get('richResultsResult',{})
if rich:
  print(f\"  Rich results:   {rich.get('verdict','-')}\")
  for d in rich.get('detectedItems',[]):
    print(f\"    - {d.get('richResultType','-')}: {[i.get('name','') for i in d.get('items',[])]}\")
" 2>/dev/null || _api_oauth -X POST \
    -H "Content-Type: application/json" \
    -d "{\"inspectionUrl\": \"$url\", \"siteUrl\": \"$SITE_URL\"}" \
    "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect" | python3 -m json.tool
}

cmd_gsc_cluster_inspect() {
  local site_key
  for site_key in "${CLUSTER_SITE_KEYS[@]}"; do
    set_current_site "$site_key"
    cmd_gsc_inspect "https://${DOMAIN}/"
    echo ""
  done
}

cmd_gsc_performance() {
  local days="${1:-28}"
  local start end
  start=$(date -d "$days days ago" +%Y-%m-%d)
  end=$(date +%Y-%m-%d)
  echo "━━━ GSC Performance ($start → $end) ━━━"
  _api_oauth -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"startDate\": \"$start\",
      \"endDate\": \"$end\",
      \"dimensions\": [\"query\"],
      \"rowLimit\": 20,
      \"dataState\": \"all\"
    }" \
    "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/searchAnalytics/query" | python3 -c "
import sys,json
data=json.load(sys.stdin)
rows=data.get('rows',[])
if not rows:
  print('  No search data yet (site may be too new)')
else:
  print(f'  {\"Query\":<40s} {\"Clicks\":>6s} {\"Impr\":>6s} {\"CTR\":>6s} {\"Pos\":>5s}')
  print(f'  {\"-\"*40} {\"-\"*6} {\"-\"*6} {\"-\"*6} {\"-\"*5}')
  for r in rows:
    q=r['keys'][0]
    print(f'  {q:<40s} {r[\"clicks\"]:>6.0f} {r[\"impressions\"]:>6.0f} {r[\"ctr\"]*100:>5.1f}% {r[\"position\"]:>5.1f}')
" 2>/dev/null || echo "  (no data or no access)"
}

cmd_gsc_pages() {
  local days="${1:-28}"
  local start end
  start=$(date -d "$days days ago" +%Y-%m-%d)
  end=$(date +%Y-%m-%d)
  echo "━━━ GSC Top Pages ($start → $end) ━━━"
  _api_oauth -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"startDate\": \"$start\",
      \"endDate\": \"$end\",
      \"dimensions\": [\"page\"],
      \"rowLimit\": 20,
      \"dataState\": \"all\"
    }" \
    "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/searchAnalytics/query" | python3 -c "
import sys,json
data=json.load(sys.stdin)
rows=data.get('rows',[])
if not rows:
  print('  No page data yet')
else:
  for r in rows:
    p=r['keys'][0]
    print(f'  {p:<60s} clicks={r[\"clicks\"]:.0f}  impr={r[\"impressions\"]:.0f}  pos={r[\"position\"]:.1f}')
" 2>/dev/null || echo "  (no data or no access)"
}

cmd_gsc_full_index() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  FULL INDEXING PUSH for $DOMAIN"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  cmd_gsc_submit_sitemap
  echo ""
  cmd_gsc_inspect "https://${DOMAIN}/"
  echo ""
  echo "━━━ Done! Next steps: ━━━"
  echo "  1. Check GSC: https://search.google.com/search-console?resource_id=${SITE_URL}"
  echo "  2. Monitor: ./manage-google.sh gsc-performance"
  echo "  3. Re-check indexing in 24-48h: ./manage-google.sh gsc-inspect"
}

# ── FinOps / Cost monitoring ─────────────────────────────────────────
GCP_PROJECT="carta-astral-f4ab9"
CLOUD_RUN_SERVICE="carta-astral-api"
CLOUD_RUN_REGION="europe-west1"

cmd_finops_cloud_run() {
  echo "━━━ Cloud Run — Config actual ━━━"
  gcloud run services describe "$CLOUD_RUN_SERVICE" \
    --region="$CLOUD_RUN_REGION" --project="$GCP_PROJECT" \
    --format="table(spec.template.spec.containers[0].resources.limits,spec.template.metadata.annotations)" 2>/dev/null || true

  echo ""
  echo "━━━ Cloud Run — Revisiones activas ━━━"
  gcloud run revisions list --service="$CLOUD_RUN_SERVICE" \
    --region="$CLOUD_RUN_REGION" --project="$GCP_PROJECT" \
    --format="table(metadata.name,status.conditions[0].type,spec.containerConcurrency,metadata.annotations['autoscaling.knative.dev/maxScale'])" \
    --limit=3 2>/dev/null || true

  echo ""
  echo "━━━ Cloud Run — Métricas últimas 24h ━━━"
  local now end
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  end=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)
  gcloud monitoring time-series list \
    --project="$GCP_PROJECT" \
    --filter="metric.type=\"run.googleapis.com/request_count\" AND resource.labels.service_name=\"$CLOUD_RUN_SERVICE\"" \
    --interval-start="$end" --format=json 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
total=sum(int(p.get('value',{}).get('int64Value',0)) for ts in data for p in ts.get('points',[]))
print(f'  Requests totales: {total}')
" 2>/dev/null || echo "  (no hay datos de métricas aún)"
}

cmd_finops_billing() {
  echo "━━━ Billing — Presupuestos activos ━━━"
  local billing_account
  billing_account=$(gcloud billing projects describe "$GCP_PROJECT" --format="value(billingAccountName)" 2>/dev/null)
  if [[ -n "$billing_account" ]]; then
    gcloud billing budgets list --billing-account="${billing_account##*/}" \
      --format="table(displayName,amount.specifiedAmount.currencyCode,amount.specifiedAmount.units,budgetFilter.projects)" 2>/dev/null || true
  else
    echo "  No se encontró cuenta de facturación"
  fi

  echo ""
  echo "━━━ Billing — Servicios habilitados (APIs de pago) ━━━"
  gcloud services list --enabled --project="$GCP_PROJECT" \
    --filter="name:(generativelanguage OR run OR cloudbuild)" \
    --format="table(name,title)" 2>/dev/null || true
}

cmd_finops_summary() {
  echo "╔══════════════════════════════════════╗"
  echo "║   FinOps Dashboard — Free Tier       ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  cmd_finops_cloud_run
  echo ""
  cmd_finops_billing
  echo ""
  echo "━━━ Free Tier Limits (recordatorio) ━━━"
  echo "  Cloud Run:   180,000 vCPU-s/mes, 360,000 GiB-s/mes, 2M requests/mes"
  echo "  Firebase:    10 GB hosting, 360 MB/día transfer"
  echo "  Gemini Flash: 15 RPM / 1500 RPD / 1M tokens/min free tier"
  echo "  GitHub Actions: 2000 min/mes (public repos)"
}

cmd_help() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]
       $(basename "$0") --site <site-key|domain> <command> [args]

  GA4:
    status              Full status (GA4 + AdSense)
    ga4-realtime        Active users right now
    ga4-report [days]   Traffic report (default: 7 days)
    ga4-top-pages [d]   Top pages by views (default: 30 days)
    ga4-key-events      List key events (conversions)
    ga4-custom-dimensions      List current vs desired custom dimensions
    ga4-apply-custom-dimensions Create missing GA4 custom dimensions
    ga4-sync-key-events Create missing GA4 key events from manifest
    ga4-watch-admin     Compare GA4 Admin config with repo manifests
    ga4-sync-admin      Sync custom dimensions + key events
    ga4-create-key-event <name>  Create a key event

  AdSense:
    adsense-earnings [d] Earnings report (default: 7 days)
    adsense-sites       Site approval status
    adsense-alerts      Active alerts/warnings
    google-auth-audit   OAuth scopes + Analytics auth status

  Google Search Console:
    gsc-sites           List verified sites
    gsc-submit-sitemap  Submit sitemap.xml to GSC
    gsc-submit-sitemaps-all Submit sitemap.xml for all cluster sites
    gsc-sitemaps        Show sitemap status in GSC
    gsc-inspect [url]   URL Inspection (indexing, mobile, rich results)
    gsc-cluster-inspect Inspect the homepage for all cluster sites
    gsc-performance [d] Search queries + clicks + impressions (default: 28d)
    gsc-pages [d]       Top pages by search performance
    gsc-full-index      Full indexing push (submit + inspect)

  FinOps:
    finops              Full FinOps dashboard (Cloud Run + Billing)
    finops-cloud-run    Cloud Run config, revisions & metrics
    finops-billing      Budgets & enabled paid APIs

  help                This message
EOF
}

# ── Dispatch ─────────────────────────────────────────────────────────
if [[ "${1:-}" == "--site" ]]; then
  set_current_site "${2:-}"
  shift 2
fi

case "${1:-help}" in
  status)               cmd_status ;;
  ga4-realtime)         cmd_ga4_realtime ;;
  ga4-report)           cmd_ga4_report "${2:-7}" ;;
  ga4-top-pages)        cmd_ga4_top_pages "${2:-30}" ;;
  ga4-key-events)       cmd_ga4_key_events ;;
  ga4-custom-dimensions) cmd_ga4_custom_dimensions ;;
  ga4-apply-custom-dimensions) cmd_ga4_apply_custom_dimensions ;;
  ga4-sync-key-events)  cmd_ga4_sync_key_events ;;
  ga4-watch-admin)      cmd_ga4_watch_admin ;;
  ga4-sync-admin)       cmd_ga4_sync_admin ;;
  ga4-create-key-event) cmd_ga4_create_key_event "${2:-}" ;;
  adsense-earnings)     cmd_adsense_earnings "${2:-7}" ;;
  adsense-sites)        cmd_adsense_sites ;;
  adsense-alerts)       cmd_adsense_alerts ;;
  google-auth-audit)    cmd_google_auth_audit ;;
  gsc-sites)            cmd_gsc_sites ;;
  gsc-submit-sitemap)   cmd_gsc_submit_sitemap "${2:-}" ;;
  gsc-submit-sitemaps-all) cmd_gsc_submit_sitemaps_all ;;
  gsc-sitemaps)         cmd_gsc_sitemaps ;;
  gsc-inspect)          cmd_gsc_inspect "${2:-}" ;;
  gsc-cluster-inspect)  cmd_gsc_cluster_inspect ;;
  gsc-performance)      cmd_gsc_performance "${2:-28}" ;;
  gsc-pages)            cmd_gsc_pages "${2:-28}" ;;
  gsc-full-index)       cmd_gsc_full_index ;;
  finops)               cmd_finops_summary ;;
  finops-cloud-run)     cmd_finops_cloud_run ;;
  finops-billing)       cmd_finops_billing ;;
  help|*)               cmd_help ;;
esac
