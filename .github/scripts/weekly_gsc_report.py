#!/usr/bin/env python3
import json
import os
import urllib.parse
import urllib.request


sites = json.loads(os.environ["GSC_SITES_JSON"])
token = os.environ["OAUTH_TOKEN"]
start = os.environ["GSC_START"]
end = os.environ["GSC_END"]


def fetch(site_url, payload):
    encoded = urllib.parse.quote(site_url, safe="")
    req = urllib.request.Request(
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{encoded}/searchAnalytics/query",
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return {}


def safe_text(value):
    return str(value).replace("|", "\\|")


cluster = {"clicks": 0.0, "impressions": 0.0}
site_reports = []

for site_key, domain, site_url in sites:
    totals = fetch(
        site_url,
        {
            "startDate": start,
            "endDate": end,
            "dataState": "all",
        },
    )
    queries = fetch(
        site_url,
        {
            "startDate": start,
            "endDate": end,
            "dimensions": ["query"],
            "rowLimit": 5,
            "dataState": "all",
        },
    )
    pages = fetch(
        site_url,
        {
            "startDate": start,
            "endDate": end,
            "dimensions": ["page"],
            "rowLimit": 5,
            "dataState": "all",
        },
    )

    total_row = (totals.get("rows") or [{}])[0]
    clicks = float(total_row.get("clicks", 0) or 0)
    impressions = float(total_row.get("impressions", 0) or 0)
    ctr = float(total_row.get("ctr", 0) or 0)
    position = float(total_row.get("position", 0) or 0)
    cluster["clicks"] += clicks
    cluster["impressions"] += impressions
    site_reports.append(
        {
            "site_key": site_key,
            "domain": domain,
            "clicks": clicks,
            "impressions": impressions,
            "ctr": ctr,
            "position": position,
            "queries": queries.get("rows", []),
            "pages": pages.get("rows", []),
        }
    )

site_reports.sort(key=lambda item: item["clicks"], reverse=True)
cluster_ctr = (cluster["clicks"] / cluster["impressions"]) if cluster["impressions"] else 0.0

print("#### Cluster Totals")
print("| Site | Clicks | Impressions | CTR | Position |")
print("|------|--------|-------------|-----|----------|")
for report in site_reports:
    print(
        f"| {report['domain']} | {report['clicks']:.0f} | {report['impressions']:.0f} | "
        f"{report['ctr'] * 100:.1f}% | {report['position']:.1f} |"
    )
print(
    f"| **Total cluster** | **{cluster['clicks']:.0f}** | **{cluster['impressions']:.0f}** | "
    f"**{cluster_ctr * 100:.1f}%** | **-** |"
)

for report in site_reports:
    print()
    print(f"#### {report['domain']}")
    if report["impressions"] <= 0 and not report["queries"] and not report["pages"]:
        print("> No search data yet")
        continue
    print(
        f"**Totals**: {report['clicks']:.0f} clicks, {report['impressions']:.0f} impressions, "
        f"{report['ctr'] * 100:.1f}% CTR, avg pos {report['position']:.1f}"
    )
    print()
    print("| Query | Clicks | Impressions | CTR | Position |")
    print("|-------|--------|-------------|-----|----------|")
    if report["queries"]:
        for row in report["queries"]:
            query = safe_text(row["keys"][0])
            print(
                f"| {query} | {row.get('clicks', 0):.0f} | {row.get('impressions', 0):.0f} | "
                f"{row.get('ctr', 0) * 100:.1f}% | {row.get('position', 0):.1f} |"
            )
    else:
        print("| No data yet | 0 | 0 | 0.0% | - |")

    print()
    print("| Page | Clicks | Impressions | Position |")
    print("|------|--------|-------------|----------|")
    if report["pages"]:
        base = f"https://{report['domain']}"
        for row in report["pages"]:
            page = safe_text(row["keys"][0].replace(base, "") or "/")
            print(
                f"| {page} | {row.get('clicks', 0):.0f} | {row.get('impressions', 0):.0f} | "
                f"{row.get('position', 0):.1f} |"
            )
    else:
        print("| No data yet | 0 | 0 | - |")
