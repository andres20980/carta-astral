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


def list_key_events(property_name, token):
    status, payload = api_json(
        f"https://analyticsadmin.googleapis.com/v1beta/{property_name}/keyEvents?pageSize=200",
        token,
    )
    if status >= 400:
        raise RuntimeError(payload.get("error", {}).get("message", f"HTTP {status}"))
    return payload.get("keyEvents", [])


def create_key_event(property_name, token, item):
    status, payload = api_json(
        f"https://analyticsadmin.googleapis.com/v1beta/{property_name}/keyEvents",
        token,
        method="POST",
        body={"eventName": item["eventName"]},
    )
    if status >= 400:
        raise RuntimeError(payload.get("error", {}).get("message", f"HTTP {status}"))
    return payload


def main():
    parser = argparse.ArgumentParser(description="Manage GA4 key events declaratively.")
    parser.add_argument("--property", required=True, dest="property_name")
    parser.add_argument("--token", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    desired = {item["eventName"]: item for item in manifest}

    existing = list_key_events(args.property_name, args.token)
    existing_by_name = {item.get("eventName"): item for item in existing}

    print("━━━ GA4 Key Events ━━━")
    print(f"Propiedad: {args.property_name}")
    print(f"Actuales: {len(existing_by_name)}")
    print(f"Deseados: {len(desired)}")
    print("")

    missing = []
    for event_name, wanted in desired.items():
      current = existing_by_name.get(event_name)
      if current:
          print(f"  OK    {event_name:<24} -> {wanted.get('displayName','-')}")
      else:
          print(f"  MISS  {event_name:<24} -> {wanted.get('displayName','-')}")
          missing.append(wanted)

    extras = sorted(
        name for name in existing_by_name.keys() if name and name not in desired
    )
    if extras:
        print("")
        print("Extra ya existente en GA4:")
        for name in extras:
            print(f"  EXTRA {name}")

    if not args.apply:
        return 0

    if not missing:
        print("")
        print("Sin cambios. GA4 ya esta alineado con el manifiesto de key events.")
        return 0

    print("")
    print("Creando key events faltantes...")
    created = 0
    for item in missing:
        created_item = create_key_event(args.property_name, args.token, item)
        print(
            f"  CREATED {created_item.get('eventName','-'):<20} -> {created_item.get('name','-')}"
        )
        created += 1

    print("")
    print(f"Listo. Creados: {created}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
