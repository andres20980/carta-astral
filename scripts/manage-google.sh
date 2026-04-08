#!/usr/bin/env bash
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
GA4_PROPERTY="properties/531527723"
GA4_STREAM="properties/531527723/dataStreams/14325968472"
ADSENSE_ACCOUNT="accounts/pub-9368517395014039"
DOMAIN="carta-astral-gratis.es"
SITE_URL="sc-domain:${DOMAIN}"   # GSC property (domain-level)
SITE_URL_ENC="sc-domain%3A${DOMAIN}"
SITEMAP_URL="https://${DOMAIN}/sitemap.xml"

_token() { gcloud auth application-default print-access-token; }
_api()   { curl -s -H "Authorization: Bearer $(_token)" "$@"; }

# ── Commands ─────────────────────────────────────────────────────────

cmd_status() {
  echo "━━━ GA4 Property ━━━"
  _api "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY" | python3 -m json.tool

  echo ""
  echo "━━━ GA4 Data Streams ━━━"
  _api "https://analyticsadmin.googleapis.com/v1beta/$GA4_PROPERTY/dataStreams" | python3 -m json.tool

  echo ""
  echo "━━━ AdSense Sites ━━━"
  _api "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/sites" | python3 -m json.tool

  echo ""
  echo "━━━ AdSense Ad Clients ━━━"
  _api "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/adclients" | python3 -m json.tool
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
  _api "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/reports:generate?\
dateRange=CUSTOM&\
startDate.year=$(date -d "$start" +%Y)&startDate.month=$(date -d "$start" +%-m)&startDate.day=$(date -d "$start" +%-d)&\
endDate.year=$(date -d "$end" +%Y)&endDate.month=$(date -d "$end" +%-m)&endDate.day=$(date -d "$end" +%-d)&\
metrics=ESTIMATED_EARNINGS&metrics=PAGE_VIEWS&metrics=IMPRESSIONS&metrics=CLICKS&\
dimensions=DATE&\
reportingTimeZone=ACCOUNT_TIME_ZONE" | python3 -m json.tool
}

cmd_adsense_sites() {
  echo "━━━ AdSense Sites ━━━"
  _api "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/sites" | python3 -m json.tool
}

cmd_adsense_alerts() {
  echo "━━━ AdSense Alerts ━━━"
  _api "https://adsense.googleapis.com/v2/$ADSENSE_ACCOUNT/alerts" | python3 -m json.tool
}

# ── Google Search Console ────────────────────────────────────────────

cmd_gsc_sites() {
  echo "━━━ GSC Verified Sites ━━━"
  _api "https://searchconsole.googleapis.com/webmasters/v3/sites" | python3 -c "
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
  resp=$(_api -X PUT -w "\n%{http_code}" \
    "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/sitemaps/$(python3 -c "import urllib.parse;print(urllib.parse.quote('$sitemap',''))")")
  local code
  code=$(echo "$resp" | tail -1)
  if [[ "$code" == "204" ]] || [[ "$code" == "200" ]]; then
    echo "  ✅ Sitemap submitted successfully"
  else
    echo "  Response (HTTP $code):"
    echo "$resp" | head -n -1 | python3 -m json.tool 2>/dev/null || echo "$resp"
  fi
}

cmd_gsc_sitemaps() {
  echo "━━━ GSC Sitemaps ━━━"
  _api "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL_ENC}/sitemaps" | python3 -c "
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

cmd_gsc_inspect() {
  local url="${1:-https://${DOMAIN}/}"
  echo "━━━ URL Inspection: $url ━━━"
  _api -X POST \
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
" 2>/dev/null || _api -X POST \
    -H "Content-Type: application/json" \
    -d "{\"inspectionUrl\": \"$url\", \"siteUrl\": \"$SITE_URL\"}" \
    "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect" | python3 -m json.tool
}

cmd_gsc_performance() {
  local days="${1:-28}"
  local start end
  start=$(date -d "$days days ago" +%Y-%m-%d)
  end=$(date +%Y-%m-%d)
  echo "━━━ GSC Performance ($start → $end) ━━━"
  _api -X POST \
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
  _api -X POST \
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

cmd_gsc_ping_sitemap() {
  echo "━━━ Ping Search Engines ━━━"
  echo "  Pinging Google..."
  local g_code
  g_code=$(curl -s -o /dev/null -w "%{http_code}" "https://www.google.com/ping?sitemap=${SITEMAP_URL}")
  echo "  Google: HTTP $g_code $([ "$g_code" = "200" ] && echo '✅' || echo '⚠️')"

  echo "  Pinging Bing..."
  local b_code
  b_code=$(curl -s -o /dev/null -w "%{http_code}" "https://www.bing.com/indexnow?url=${SITEMAP_URL}")
  echo "  Bing: HTTP $b_code $([ "$b_code" = "200" ] && echo '✅' || echo '⚠️')"

  echo "  Pinging IndexNow (Yandex/Bing)..."
  local i_code
  i_code=$(curl -s -o /dev/null -w "%{http_code}" "https://yandex.com/indexnow?url=https://${DOMAIN}/&key=${DOMAIN}")
  echo "  IndexNow: HTTP $i_code $([ "$i_code" = "200" ] && echo '✅' || echo '⚠️')"
}

cmd_gsc_full_index() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  FULL INDEXING PUSH for $DOMAIN"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  cmd_gsc_submit_sitemap
  echo ""
  cmd_gsc_ping_sitemap
  echo ""
  cmd_gsc_inspect "https://${DOMAIN}/"
  echo ""
  echo "━━━ Done! Next steps: ━━━"
  echo "  1. Check GSC: https://search.google.com/search-console?resource_id=${SITE_URL}"
  echo "  2. Monitor: ./manage-google.sh gsc-performance"
  echo "  3. Re-check indexing in 24-48h: ./manage-google.sh gsc-inspect"
}

cmd_help() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

  GA4:
    status              Full status (GA4 + AdSense)
    ga4-realtime        Active users right now
    ga4-report [days]   Traffic report (default: 7 days)
    ga4-top-pages [d]   Top pages by views (default: 30 days)
    ga4-key-events      List key events (conversions)
    ga4-create-key-event <name>  Create a key event

  AdSense:
    adsense-earnings [d] Earnings report (default: 7 days)
    adsense-sites       Site approval status
    adsense-alerts      Active alerts/warnings

  Google Search Console:
    gsc-sites           List verified sites
    gsc-submit-sitemap  Submit sitemap.xml to GSC
    gsc-sitemaps        Show sitemap status in GSC
    gsc-inspect [url]   URL Inspection (indexing, mobile, rich results)
    gsc-performance [d] Search queries + clicks + impressions (default: 28d)
    gsc-pages [d]       Top pages by search performance
    gsc-ping-sitemap    Ping Google + Bing + IndexNow with sitemap
    gsc-full-index      Full indexing push (submit + ping + inspect)

  help                This message
EOF
}

# ── Dispatch ─────────────────────────────────────────────────────────
case "${1:-help}" in
  status)               cmd_status ;;
  ga4-realtime)         cmd_ga4_realtime ;;
  ga4-report)           cmd_ga4_report "${2:-7}" ;;
  ga4-top-pages)        cmd_ga4_top_pages "${2:-30}" ;;
  ga4-key-events)       cmd_ga4_key_events ;;
  ga4-create-key-event) cmd_ga4_create_key_event "${2:-}" ;;
  adsense-earnings)     cmd_adsense_earnings "${2:-7}" ;;
  adsense-sites)        cmd_adsense_sites ;;
  adsense-alerts)       cmd_adsense_alerts ;;
  gsc-sites)            cmd_gsc_sites ;;
  gsc-submit-sitemap)   cmd_gsc_submit_sitemap "${2:-}" ;;
  gsc-sitemaps)         cmd_gsc_sitemaps ;;
  gsc-inspect)          cmd_gsc_inspect "${2:-}" ;;
  gsc-performance)      cmd_gsc_performance "${2:-28}" ;;
  gsc-pages)            cmd_gsc_pages "${2:-28}" ;;
  gsc-ping-sitemap)     cmd_gsc_ping_sitemap ;;
  gsc-full-index)       cmd_gsc_full_index ;;
  help|*)               cmd_help ;;
esac
