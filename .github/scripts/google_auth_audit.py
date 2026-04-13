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

REQUIRED_SCOPES = {
    "Search Console": [
        "https://www.googleapis.com/auth/webmasters",
        "https://www.googleapis.com/auth/siteverification",
    ],
    "AdSense": [
        "https://www.googleapis.com/auth/adsense.readonly",
    ],
}

OPTIONAL_SCOPE_GROUPS = {
    "Analytics OAuth (opcional)": [
        [
            "https://www.googleapis.com/auth/analytics.readonly",
            "https://www.googleapis.com/auth/analytics.edit",
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


def scope_status(required_scopes):
    missing = [scope for scope in required_scopes if scope not in scopes]
    return ("OK", missing) if not missing else ("Falta scope", missing)


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

for system, required in REQUIRED_SCOPES.items():
    if not token:
        status = "No configurado"
        detail = "No hay refresh token disponible"
    elif tokeninfo_error:
        status = "Error"
        detail = tokeninfo_error
    else:
        status, missing = scope_status(required)
        detail = "Todos los scopes presentes" if not missing else ", ".join(missing)
    print(f"| {system} | OAuth de usuario | {status} | {detail} |")

for system, scope_groups in OPTIONAL_SCOPE_GROUPS.items():
    if not token:
        status = "No configurado"
        detail = "No hay refresh token disponible"
    elif tokeninfo_error:
        status = "Error"
        detail = tokeninfo_error
    else:
        status, missing_groups = grouped_scope_status(scope_groups)
        if not missing_groups:
            detail = "Disponible"
        else:
            detail = " o ".join(" / ".join(group) for group in missing_groups)
    print(f"| {system} | OAuth de usuario | {status} | {detail} |")

print("")
print(f"{subheading_level} Modelo recomendado del cluster")
print("- `Analytics / GA4`: service account en CI para reporting estable y sin interacción.")
print("- `Search Console`, `Site Verification` y `AdSense`: OAuth de usuario porque son APIs ligadas a la cuenta propietaria.")
print("- `analytics.readonly` o `analytics.edit` en OAuth es opcional; útil para depuración y Admin API, pero no necesario para el pipeline principal.")

if token and not tokeninfo_error:
    missing_required = {
        system: [scope for scope in required if scope not in scopes]
        for system, required in REQUIRED_SCOPES.items()
    }
    blocking = {system: missing for system, missing in missing_required.items() if missing}
    print("")
    if blocking:
        print(f"{subheading_level} Acciones pendientes")
        for system, missing in blocking.items():
            print(f"- `{system}`: faltan {', '.join(f'`{scope}`' for scope in missing)}")
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
