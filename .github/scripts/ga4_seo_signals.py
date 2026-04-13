#!/usr/bin/env python3
import argparse
import json
import os
import urllib.request


def api_post(url, token, payload):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def normalize_path(value):
    value = (value or "").strip()
    if not value:
        return "/"
    if value.startswith("http://") or value.startswith("https://"):
        return value
    return value.split("?", 1)[0] or "/"


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def main():
    parser = argparse.ArgumentParser(description="Generate GA4 SEO signals for cluster sites.")
    parser.add_argument("--property", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--sites-json", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--start-date", default="7daysAgo")
    parser.add_argument("--end-date", default="today")
    args = parser.parse_args()

    sites = json.loads(args.sites_json)
    api = f"https://analyticsdata.googleapis.com/v1beta/{args.property}:runReport"

    for site_key, domain, _site_url in sites:
        payload = {
            "dateRanges": [{"startDate": args.start_date, "endDate": args.end_date}],
            "dimensions": [{"name": "hostName"}, {"name": "pagePathPlusQueryString"}],
            "metrics": [
                {"name": "screenPageViews"},
                {"name": "bounceRate"},
                {"name": "averageSessionDuration"},
            ],
            "dimensionFilter": {
                "filter": {
                    "fieldName": "hostName",
                    "stringFilter": {"matchType": "EXACT", "value": domain},
                }
            },
            "orderBys": [{"metric": {"metricName": "screenPageViews"}, "desc": True}],
            "limit": 25,
        }

        try:
            data = api_post(api, args.token, payload)
        except Exception as exc:
            data = {"error": str(exc), "rows": []}

        pages = []
        for row in data.get("rows", []):
            dims = row.get("dimensionValues", [])
            metrics = row.get("metricValues", [])
            path = normalize_path(dims[1]["value"] if len(dims) > 1 else "/")
            pages.append(
                {
                    "path": path,
                    "views": float(metrics[0]["value"]) if len(metrics) > 0 else 0.0,
                    "bounceRate": float(metrics[1]["value"]) if len(metrics) > 1 else 0.0,
                    "averageSessionDuration": float(metrics[2]["value"]) if len(metrics) > 2 else 0.0,
                }
            )

        homepage = next((page for page in pages if page["path"] == "/"), None)
        weak_homepage = False
        if homepage:
            weak_homepage = homepage["views"] >= 25 and (
                homepage["bounceRate"] >= 0.65 or homepage["averageSessionDuration"] < 45
            )

        payload = {
            "generatedAt": os.environ.get("GA4_GENERATED_AT", ""),
            "site": site_key,
            "domain": domain,
            "range": {"start": args.start_date, "end": args.end_date},
            "homepage": homepage,
            "weakHomepageEngagement": weak_homepage,
            "pages": pages[:10],
        }

        target_dir = os.path.join(args.output_dir, site_key, "docs")
        ensure_dir(target_dir)
        with open(os.path.join(target_dir, "SEO_GA4_PAGES.json"), "w") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
