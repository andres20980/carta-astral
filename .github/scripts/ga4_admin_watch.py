#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


def api_json(url, token):
    headers = {"Authorization": f"Bearer {token}"}
    quota_project = os.environ.get("GOOGLE_CLOUD_QUOTA_PROJECT", "").strip()
    include_quota_project = os.environ.get("GOOGLE_INCLUDE_QUOTA_PROJECT_HEADER", "").strip() == "1"
    if include_quota_project and quota_project:
        headers["x-goog-user-project"] = quota_project
    req = urllib.request.Request(
        url,
        headers=headers,
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode()), None
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        try:
            payload = json.loads(body)
        except Exception:
            payload = {"error": {"code": exc.code, "message": body.strip() or str(exc)}}
        return payload, payload.get("error") or {"code": exc.code, "message": str(exc)}
    except Exception as exc:
        return {}, {"message": str(exc)}


def err_msg(error):
    if not error:
        return ""
    msg = error.get("message", "Error desconocido")
    status = error.get("status")
    code = error.get("code")
    prefix = " / ".join(str(part) for part in [code, status] if part)
    return f"{prefix}: {msg}" if prefix else msg


def main():
    parser = argparse.ArgumentParser(description="Report GA4 Admin configuration drift.")
    parser.add_argument("--property", required=True, dest="property_name")
    parser.add_argument("--token", required=True)
    parser.add_argument("--dimensions-manifest", required=True)
    parser.add_argument("--key-events-manifest", required=True)
    parser.add_argument("--heading-level", default="###")
    parser.add_argument("--title", default="⚙️ Estado de configuración GA4")
    args = parser.parse_args()

    desired_dimensions = json.loads(Path(args.dimensions_manifest).read_text(encoding="utf-8"))
    desired_key_events = json.loads(Path(args.key_events_manifest).read_text(encoding="utf-8"))

    dims_payload, dims_error = api_json(
        f"https://analyticsadmin.googleapis.com/v1alpha/{args.property_name}/customDimensions?pageSize=200",
        args.token,
    )
    events_payload, events_error = api_json(
        f"https://analyticsadmin.googleapis.com/v1beta/{args.property_name}/keyEvents?pageSize=200",
        args.token,
    )

    existing_dims = {item.get("parameterName", "") for item in dims_payload.get("customDimensions", [])}
    existing_events = {item.get("eventName", "") for item in events_payload.get("keyEvents", [])}

    desired_dim_names = [item["parameterName"] for item in desired_dimensions]
    desired_event_names = [item["eventName"] for item in desired_key_events]

    missing_dims = [name for name in desired_dim_names if name not in existing_dims] if not dims_error else desired_dim_names
    missing_events = [name for name in desired_event_names if name not in existing_events] if not events_error else desired_event_names

    print(f"{args.heading_level} {args.title}")
    print("")

    if dims_error and events_error:
        print(f"> No se pudo consultar la Admin API de GA4: {err_msg(dims_error)}")
        return 0

    print("| Bloque | Estado | Cobertura |")
    print("|--------|--------|-----------|")
    dim_cov = f"{len(desired_dim_names)-len(missing_dims)}/{len(desired_dim_names)}"
    evt_cov = f"{len(desired_event_names)-len(missing_events)}/{len(desired_event_names)}"
    print(f"| Custom dimensions | {'OK' if not missing_dims else 'Pendiente'} | {dim_cov} |")
    print(f"| Key events | {'OK' if not missing_events else 'Pendiente'} | {evt_cov} |")

    print("")
    if dims_error:
        print(f"- Custom dimensions: {err_msg(dims_error)}")
    elif missing_dims:
        print(f"- Faltan custom dimensions: {', '.join(f'`{name}`' for name in missing_dims)}")
    else:
        print("- Custom dimensions: alineadas con el manifiesto.")

    if events_error:
        print(f"- Key events: {err_msg(events_error)}")
    elif missing_events:
        print(f"- Faltan key events: {', '.join(f'`{name}`' for name in missing_events)}")
    else:
        print("- Key events: alineados con el manifiesto.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
