#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


def api_json(url, token, method="GET", body=None):
    data = None
    headers = {"Authorization": f"Bearer {token}"}
    quota_project = os.environ.get("GOOGLE_CLOUD_QUOTA_PROJECT", "").strip()
    include_quota_project = os.environ.get("GOOGLE_INCLUDE_QUOTA_PROJECT_HEADER", "").strip() == "1"
    if include_quota_project and quota_project:
        headers["x-goog-user-project"] = quota_project
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {"error": {"message": raw or str(exc)}}
        return exc.code, payload


def list_custom_dimensions(property_name, token):
    status, payload = api_json(
        f"https://analyticsadmin.googleapis.com/v1alpha/{property_name}/customDimensions?pageSize=200",
        token,
    )
    if status >= 400:
        raise RuntimeError(payload.get("error", {}).get("message", f"HTTP {status}"))
    return payload.get("customDimensions", [])


def create_custom_dimension(property_name, token, item):
    status, payload = api_json(
        f"https://analyticsadmin.googleapis.com/v1alpha/{property_name}/customDimensions",
        token,
        method="POST",
        body=item,
    )
    if status >= 400:
        raise RuntimeError(payload.get("error", {}).get("message", f"HTTP {status}"))
    return payload


def main():
    parser = argparse.ArgumentParser(description="Manage GA4 custom dimensions declaratively.")
    parser.add_argument("--property", required=True, dest="property_name")
    parser.add_argument("--token", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    desired = {item["parameterName"]: item for item in manifest}

    existing = list_custom_dimensions(args.property_name, args.token)
    existing_by_param = {item.get("parameterName"): item for item in existing}

    print("━━━ GA4 Custom Dimensions ━━━")
    print(f"Propiedad: {args.property_name}")
    print(f"Actuales: {len(existing_by_param)}")
    print(f"Deseadas: {len(desired)}")
    print("")

    missing = []
    for parameter_name, wanted in desired.items():
        current = existing_by_param.get(parameter_name)
        if current:
            print(
                f"  OK    {parameter_name:<20} -> {current.get('displayName','-')}"
            )
        else:
            print(
                f"  MISS  {parameter_name:<20} -> {wanted.get('displayName','-')}"
            )
            missing.append(wanted)

    extras = sorted(
        param for param in existing_by_param.keys() if param and param not in desired
    )
    if extras:
        print("")
        print("Extra ya existente en GA4:")
        for param in extras:
            print(f"  EXTRA {param}")

    if not args.apply:
        return 0

    if not missing:
        print("")
        print("Sin cambios. GA4 ya esta alineado con el manifiesto.")
        return 0

    print("")
    print("Creando dimensiones faltantes...")
    created = 0
    for item in missing:
        payload = {
            "parameterName": item["parameterName"],
            "displayName": item["displayName"],
            "description": item.get("description", ""),
            "scope": item.get("scope", "EVENT"),
        }
        created_item = create_custom_dimension(args.property_name, args.token, payload)
        print(
            f"  CREATED {created_item.get('parameterName','-'):<16} -> {created_item.get('name','-')}"
        )
        created += 1

    print("")
    print(f"Listo. Creadas: {created}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
