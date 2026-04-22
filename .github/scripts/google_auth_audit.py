#!/usr/bin/env python3
import json
import os
import urllib.parse
import urllib.request


token = os.environ.get("OAUTH_TOKEN", "").strip()
include_raw = os.environ.get("GOOGLE_AUTH_INCLUDE_RAW_JSON", "1") != "0"
heading_level = os.environ.get("GOOGLE_AUTH_HEADING_LEVEL", "##")
heading_title = os.environ.get("GOOGLE_AUTH_REPORT_TITLE", "🔐 Auditoría de autenticación Google")
subheading_level = heading_level + "#"
analytics_sa_status = os.environ.get("ANALYTICS_SA_STATUS", "Sin comprobar")

REQUIRED_SCOPE_GROUPS = {
    "Search Console": [
        ["https://www.googleapis.com/auth/webmasters"],
        [
            "https://www.googleapis.com/auth/siteverification",
            "https://www.googleapis.com/auth/cloud-platform",
        ],
    ],
    "AdSense": [
        [
            "https://www.googleapis.com/auth/adsense.readonly",
            "https://www.googleapis.com/auth/adsense",
        ],
    ],
}


def fetch_json(url):
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode()), None
    except Exception as exc:
        return {}, str(exc)


scopes = set()
tokeninfo = {}
tokeninfo_error = ""
if token:
    tokeninfo_url = "https://www.googleapis.com/oauth2/v3/tokeninfo?" + urllib.parse.urlencode(
        {"access_token": token}
    )
    tokeninfo, tokeninfo_error = fetch_json(tokeninfo_url)
    scopes = set((tokeninfo.get("scope") or "").split())


def grouped_scope_status(scope_groups):
    missing_groups = []
    for group in scope_groups:
        if not any(scope in scopes for scope in group):
            missing_groups.append(group)
    return ("OK", missing_groups) if not missing_groups else ("Falta scope", missing_groups)


print(f"{heading_level} {heading_title}")
print("")
print("| Sistema | Tipo de acceso | Estado | Detalle |")
print("|---------|----------------|--------|---------|")

if token:
    oauth_status = "OK" if not tokeninfo_error else "Error"
    oauth_detail = tokeninfo_error or f"{len(scopes)} scopes detectados"
else:
    oauth_status = "No configurado"
    oauth_detail = "Faltan GOOGLE_OAUTH_*"
print(f"| OAuth de usuario | OAuth 2.0 refresh token | {oauth_status} | {oauth_detail} |")

if analytics_sa_status.startswith("OK"):
    analytics_state = "OK"
elif analytics_sa_status.startswith("No comprobado"):
    analytics_state = "No comprobado"
else:
    analytics_state = "Pendiente"
print(f"| Analytics CI | Service account / ADC | {analytics_state} | {analytics_sa_status} |")

for system, scope_groups in REQUIRED_SCOPE_GROUPS.items():
    if not token:
        status = "No configurado"
        detail = "No hay refresh token disponible"
    elif tokeninfo_error:
        status = "Error"
        detail = tokeninfo_error
    else:
        status, missing_groups = grouped_scope_status(scope_groups)
        detail = "Todos los scopes presentes" if not missing_groups else " o ".join(
            " / ".join(group) for group in missing_groups
        )
    print(f"| {system} | OAuth de usuario | {status} | {detail} |")

print("")
print(f"{subheading_level} Modelo recomendado del cluster")
print("- `Analytics / GA4`: service account en CI para reporting estable y sin interacción.")
print("- `Search Console`, `Site Verification` y `AdSense`: OAuth de usuario porque son APIs ligadas a la cuenta propietaria.")
print("- `GA4 Admin`: service account en CI con permisos en la propiedad para crear dimensiones personalizadas y eventos clave.")

if token and not tokeninfo_error:
    missing_required = {}
    for system, scope_groups in REQUIRED_SCOPE_GROUPS.items():
        missing_groups = [group for group in scope_groups if not any(scope in scopes for scope in group)]
        if missing_groups:
            missing_required[system] = missing_groups
    print("")
    if missing_required:
        print(f"{subheading_level} Acciones pendientes")
        for system, missing_groups in missing_required.items():
            alternatives = " y ".join(
                " / ".join(f"`{scope}`" for scope in group) for group in missing_groups
            )
            print(f"- `{system}`: faltan {alternatives}")
    else:
        print(f"{subheading_level} ✅ OAuth listo para GSC y AdSense")

if include_raw:
    print("")
    print("```json")
    print(
        json.dumps(
            {
                "tokeninfo": tokeninfo,
                "tokeninfo_error": tokeninfo_error,
                "scopes": sorted(scopes),
                "analytics_sa_status": analytics_sa_status,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    print("```")
