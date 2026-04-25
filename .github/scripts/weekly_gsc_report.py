#!/usr/bin/env python3
import json
import os
import urllib.parse
import urllib.request


sites = json.loads(os.environ["GSC_SITES_JSON"])
token = os.environ["OAUTH_TOKEN"]
start = os.environ["GSC_START"]
end = os.environ["GSC_END"]
output_dir = os.environ.get("GSC_OUTPUT_DIR", "").strip()
quota_project = os.environ.get("GOOGLE_CLOUD_QUOTA_PROJECT", "").strip()
GSC_ROW_LIMIT = int(os.environ.get("GSC_ROW_LIMIT", "25"))
REPORT_ROW_LIMIT = 5


def fetch(site_url, payload):
    encoded = urllib.parse.quote(site_url, safe="")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if quota_project:
        headers["X-Goog-User-Project"] = quota_project

    req = urllib.request.Request(
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{encoded}/searchAnalytics/query",
        data=json.dumps(payload).encode(),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return {}


def safe_text(value):
    return str(value).replace("|", "\\|")

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def build_query_rows(rows):
    results = []
    for row in rows or []:
        query = row.get("keys", [""])[0]
        clicks = float(row.get("clicks", 0) or 0)
        impressions = float(row.get("impressions", 0) or 0)
        ctr = float(row.get("ctr", 0) or 0)
        position = float(row.get("position", 0) or 0)
        opportunity = impressions * (1 - ctr)
        results.append(
            {
                "query": query,
                "clicks": clicks,
                "impressions": impressions,
                "ctr": ctr,
                "position": position,
                "opportunity": opportunity,
            }
        )
    results.sort(key=lambda item: item["opportunity"], reverse=True)
    return results


def normalize_page_path(page, domain):
    parsed = urllib.parse.urlparse(page)
    if parsed.netloc:
        path = parsed.path or "/"
        if parsed.query:
            path = f"{path}?{parsed.query}"
        return path
    base = f"https://{domain}"
    return page.replace(base, "") or "/"


def build_page_rows(rows, domain):
    results = []
    for row in rows or []:
        page = row.get("keys", [""])[0]
        path = normalize_page_path(page, domain)
        clicks = float(row.get("clicks", 0) or 0)
        impressions = float(row.get("impressions", 0) or 0)
        position = float(row.get("position", 0) or 0)
        ctr = (clicks / impressions) if impressions else 0.0
        opportunity = impressions * (1 - ctr)
        results.append(
            {
                "path": path,
                "clicks": clicks,
                "impressions": impressions,
                "ctr": ctr,
                "position": position,
                "opportunity": opportunity,
            }
        )
    results.sort(key=lambda item: item["opportunity"], reverse=True)
    return results


def build_striking_distance_rows(rows):
    return [
        item for item in rows
        if item["impressions"] >= 2
        and item["clicks"] == 0
        and 4 <= item["position"] <= 20
    ]


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
            "rowLimit": GSC_ROW_LIMIT,
            "dataState": "all",
        },
    )
    pages = fetch(
        site_url,
        {
            "startDate": start,
            "endDate": end,
            "dimensions": ["page"],
            "rowLimit": GSC_ROW_LIMIT,
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

    if output_dir:
        query_rows = build_query_rows(queries.get("rows", []))
        page_rows = build_page_rows(pages.get("rows", []), domain)
        payload = {
            "generatedAt": os.environ.get("GSC_GENERATED_AT", ""),
            "site": site_key,
            "domain": domain,
            "range": {"start": start, "end": end},
            "queries": query_rows,
            "pages": page_rows,
            "topOpportunities": query_rows[:REPORT_ROW_LIMIT],
            "strikingDistanceQueries": build_striking_distance_rows(query_rows)[:REPORT_ROW_LIMIT],
            "strikingDistancePages": build_striking_distance_rows(page_rows)[:REPORT_ROW_LIMIT],
        }
        target_dir = os.path.join(output_dir, site_key, "docs")
        ensure_dir(target_dir)
        with open(os.path.join(target_dir, "SEO_GSC_QUERIES.json"), "w") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

site_reports.sort(key=lambda item: item["clicks"], reverse=True)
cluster_ctr = (cluster["clicks"] / cluster["impressions"]) if cluster["impressions"] else 0.0

print("#### Totales del cluster")
print("| Dominio | Clics | Impresiones | CTR | Posición |")
print("|---------|-------|-------------|-----|----------|")
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
        print("> Aún no hay datos de búsqueda")
        continue
    print(
        f"**Totales**: {report['clicks']:.0f} clics, {report['impressions']:.0f} impresiones, "
        f"{report['ctr'] * 100:.1f}% de CTR, posición media {report['position']:.1f}"
    )
    print()
    print("| Consulta | Clics | Impresiones | CTR | Posición |")
    print("|----------|-------|-------------|-----|----------|")
    if report["queries"]:
        for row in report["queries"][:REPORT_ROW_LIMIT]:
            query = safe_text(row["keys"][0])
            print(
                f"| {query} | {row.get('clicks', 0):.0f} | {row.get('impressions', 0):.0f} | "
                f"{row.get('ctr', 0) * 100:.1f}% | {row.get('position', 0):.1f} |"
            )
    else:
        print("| Sin datos aún | 0 | 0 | 0.0% | - |")

    print()
    print("| Página | Clics | Impresiones | Posición |")
    print("|--------|-------|-------------|----------|")
    if report["pages"]:
        for row in report["pages"][:REPORT_ROW_LIMIT]:
            page = safe_text(normalize_page_path(row["keys"][0], report["domain"]))
            print(
                f"| {page} | {row.get('clicks', 0):.0f} | {row.get('impressions', 0):.0f} | "
                f"{row.get('position', 0):.1f} |"
            )
    else:
        print("| Sin datos aún | 0 | 0 | - |")
