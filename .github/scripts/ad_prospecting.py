#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


ROOT = os.environ.get("GITHUB_WORKSPACE", os.getcwd())
PROSPECTS_PATH = os.path.join(ROOT, "docs", "AD_PROSPECTS.json")
QUERIES_PATH = os.path.join(ROOT, "docs", "AD_PROSPECT_SEARCH_QUERIES.json")
STATE_PATH = os.path.join(ROOT, "docs", "AD_PROSPECTING_STATE.json")
ACCESS_DENIED_PREFIX = "Custom Search JSON API: acceso denegado para este proyecto."

def env_int(name, default, minimum=0, maximum=None):
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError:
        value = default
    value = max(minimum, value)
    if maximum is not None:
        value = min(maximum, value)
    return value


MAX_NEW = env_int("MAX_NEW_PROSPECTS", 10, minimum=0, maximum=25)
MAX_QUERIES = env_int("MAX_SEARCH_QUERIES", 5, minimum=0, maximum=5)
MAX_RESULTS_PER_QUERY = env_int("MAX_RESULTS_PER_QUERY", 5, minimum=1, maximum=10)
TIMEOUT = env_int("PROSPECT_FETCH_TIMEOUT", 12, minimum=3, maximum=20)
ACCESS_DENIED_COOLDOWN_DAYS = env_int("CUSTOM_SEARCH_ACCESS_DENIED_COOLDOWN_DAYS", 30, minimum=1, maximum=90)

EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I)
BAD_EMAIL_PARTS = {
    "example", "ejemplo", "email.com", "sentry", "wixpress", "wordpress", "domain.com",
    "yourdomain", "localhost", "noreply", "no-reply", "donotreply", "privacidad",
    "abuse", "postmaster", "hostmaster", "webmaster",
}
OWN_DOMAINS = {
    "carta-astral-gratis.es",
    "compatibilidad-signos.es",
    "tarot-del-dia.es",
    "calcular-numerologia.es",
    "horoscopo-de-hoy.es",
    "licitago.es",
}
FIT_TERMS = {
    "tarot": 4,
    "tarotista": 5,
    "vidente": 5,
    "videncia": 4,
    "astrolog": 4,
    "horoscopo": 3,
    "horóscopo": 3,
    "numerologia": 3,
    "numerología": 3,
    "esoteric": 3,
    "esoterica": 3,
    "esotérica": 3,
    "ritual": 2,
    "minerales": 2,
    "espiritual": 2,
}


def load_json(path, fallback):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return fallback


def save_json(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def config_fingerprint(api_key, cx):
    return hashlib.sha256(f"{api_key}\0{cx}".encode("utf-8")).hexdigest()[:16]


def parse_date(value):
    try:
        return dt.date.fromisoformat(value or "")
    except ValueError:
        return None


def active_access_denied_pause(state, fingerprint, today):
    if state.get("reason") != "custom_search_access_denied":
        return None
    if state.get("config_fingerprint") != fingerprint:
        return None
    disabled_until = parse_date(state.get("disabled_until"))
    if disabled_until and disabled_until >= today:
        return disabled_until
    return None


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "astro-cluster-prospecting/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_error_message(exc):
    try:
        payload = json.loads(exc.read().decode("utf-8", errors="ignore"))
    except Exception:
        return str(exc)
    error = payload.get("error", {})
    return error.get("message") or str(exc)


def is_custom_search_access_denied(message):
    return "does not have the access to custom search json api" in (message or "").lower()


def fetch_text(url):
    req = urllib.request.Request(url, headers={"User-Agent": "astro-cluster-prospecting/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        content_type = resp.headers.get("Content-Type", "")
        if "text/html" not in content_type and "text/plain" not in content_type:
            return ""
        raw = resp.read(300_000)
    return raw.decode("utf-8", errors="ignore")


def normalize_email(value):
    value = html.unescape(value or "").strip().lower().strip(".,;:()[]{}<>")
    return value


def is_good_email(email):
    if not email or "@" not in email:
        return False
    local, domain = email.rsplit("@", 1)
    if domain in OWN_DOMAINS:
        return False
    joined = f"{local}@{domain}"
    if any(part in joined for part in BAD_EMAIL_PARTS):
        return False
    if len(local) < 2 or "." not in domain:
        return False
    return True


def score_text(text):
    low = (text or "").lower()
    return sum(weight for term, weight in FIT_TERMS.items() if term in low)


def domain_country_hint(url):
    domain = urllib.parse.urlparse(url).netloc.lower()
    if domain.endswith(".es"):
        return "ES"
    if domain.endswith(".com.ar") or domain.endswith(".ar"):
        return "AR"
    if domain.endswith(".mx"):
        return "MX"
    if domain.endswith(".cl"):
        return "CL"
    if domain.endswith(".co"):
        return "CO"
    return ""


def google_search(query, api_key, cx):
    params = urllib.parse.urlencode({
        "key": api_key,
        "cx": cx,
        "q": query,
        "num": min(10, MAX_RESULTS_PER_QUERY),
        "lr": "lang_es",
        "safe": "active",
    })
    payload = fetch_json(f"https://www.googleapis.com/customsearch/v1?{params}")
    return payload.get("items", [])


def candidate_from(email, result, page_text, today):
    title = html.unescape(result.get("title", "")).strip()
    snippet = html.unescape(result.get("snippet", "")).strip()
    source_url = result.get("link", "")
    combined = f"{title}\n{snippet}\n{page_text[:5000]}"
    score = score_text(combined)
    if score < 3:
        return None
    segment = "esoterismo"
    low = combined.lower()
    if "tarot" in low:
        segment = "tarot"
    elif "astrolog" in low:
        segment = "astrologia"
    elif "numerolog" in low:
        segment = "numerologia"
    elif "tienda" in low:
        segment = "tienda esoterica"

    return {
        "email": email,
        "name": title[:120] or urllib.parse.urlparse(source_url).netloc,
        "segment": segment,
        "country_hint": domain_country_hint(source_url),
        "source_url": source_url,
        "why_fit": "Contacto publico encontrado en una pagina hispanohablante relacionada con tarot, astrologia o esoterismo.",
        "status": "new",
        "first_seen": today,
        "last_seen": today,
        "score": score,
    }


def prospect(api_key, cx, existing):
    today = dt.date.today().isoformat()
    seen = {item.get("email", "").lower() for item in existing}
    queries = load_json(QUERIES_PATH, [])
    found = []
    errors = []

    for query in queries[:MAX_QUERIES]:
        if len(found) >= MAX_NEW:
            break
        try:
            results = google_search(query, api_key, cx)
        except urllib.error.HTTPError as exc:
            message = http_error_message(exc)
            if exc.code == 403 and is_custom_search_access_denied(message):
                errors.append(
                    f"{ACCESS_DENIED_PREFIX} "
                    "Google indica que la API esta cerrada a nuevos clientes; "
                    "se detienen los reintentos para mantener la ejecucion free-tier friendly."
                )
                break
            errors.append(f"{query}: HTTP {exc.code}: {message}")
            continue
        except Exception as exc:
            errors.append(f"{query}: {exc}")
            continue

        for result in results:
            if len(found) >= MAX_NEW:
                break
            source_url = result.get("link", "")
            text = f"{result.get('title', '')}\n{result.get('snippet', '')}"
            try:
                text = f"{text}\n{fetch_text(source_url)}"
            except Exception:
                pass

            for email in sorted({normalize_email(match) for match in EMAIL_RE.findall(text)}):
                if not is_good_email(email) or email in seen:
                    continue
                candidate = candidate_from(email, result, text, today)
                if candidate:
                    found.append(candidate)
                    seen.add(email)

    return found, errors


def report(existing, added, errors, missing_config, state=None):
    lines = [
        "## Prospección diaria de anunciantes",
        "",
        f"- Candidatos nuevos: **{len(added)}**",
        f"- Total histórico: **{len(existing) + len(added)}**",
        f"- Límite de búsqueda por ejecución: **{MAX_QUERIES} consultas x {MAX_RESULTS_PER_QUERY} resultados**.",
        f"- Límite de candidatos nuevos por ejecución: **{MAX_NEW}**.",
        "- Envío automático: **solo si el candidato valida MX y fuente pública en el workflow de captación**.",
        "",
    ]
    if missing_config:
        lines += [
            "### Configuración pendiente",
            "",
            "Faltan `GOOGLE_SEARCH_API_KEY` y/o `GOOGLE_SEARCH_CX`. La acción está preparada para Google Programmable Search en free-tier.",
            "",
        ]
    if state and state.get("reason") == "custom_search_access_denied":
        lines += [
            "### Pausa FinOps",
            "",
            f"- Motivo: **Custom Search JSON API denegada para la configuracion actual**.",
            f"- Sin nuevas llamadas a la API hasta: **{state.get('disabled_until', 'sin fecha')}**.",
            "- Para reactivar antes, cambia `GOOGLE_SEARCH_API_KEY`/`GOOGLE_SEARCH_CX` o ajusta `CUSTOM_SEARCH_ACCESS_DENIED_COOLDOWN_DAYS`.",
            "",
        ]
    if added:
        lines += ["### Nuevos candidatos", "", "| Email | Nombre | Segmento | Fuente |", "|---|---|---|---|"]
        for item in added:
            lines.append(f"| `{item['email']}` | {item['name']} | {item['segment']} | {item['source_url']} |")
        lines.append("")
    if errors:
        lines += ["### Incidencias", ""]
        for error in errors[:10]:
            lines.append(f"- {error}")
        lines.append("")
    lines += [
        "### Buenas prácticas",
        "",
        "- Usar solo contactos profesionales publicados en páginas de contacto.",
        "- Personalizar el primer email y no repetir envío si no hay respuesta.",
        "- Incluir una frase de baja manual: \"Si no te interesa, dime y no vuelvo a escribirte\".",
        "- No comprar bases de datos ni automatizar envíos masivos.",
    ]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    api_key = os.environ.get("GOOGLE_SEARCH_API_KEY", "").strip()
    cx = os.environ.get("GOOGLE_SEARCH_CX", "").strip()
    existing = load_json(PROSPECTS_PATH, [])
    state = load_json(STATE_PATH, {})
    missing_config = not api_key or not cx

    added = []
    errors = []
    if not missing_config:
        today = dt.date.today()
        fingerprint = config_fingerprint(api_key, cx)
        paused_until = active_access_denied_pause(state, fingerprint, today)
        if paused_until:
            errors.append(
                f"{ACCESS_DENIED_PREFIX} Busqueda pausada hasta {paused_until.isoformat()} "
                "para evitar reintentos sin valor."
            )
        else:
            added, errors = prospect(api_key, cx, existing)
            if any(error.startswith(ACCESS_DENIED_PREFIX) for error in errors):
                state = {
                    "reason": "custom_search_access_denied",
                    "config_fingerprint": fingerprint,
                    "disabled_until": (today + dt.timedelta(days=ACCESS_DENIED_COOLDOWN_DAYS)).isoformat(),
                    "updated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                }
            elif state.get("reason") == "custom_search_access_denied":
                state = {}
        if args.write and added:
            save_json(PROSPECTS_PATH, existing + added)
        if args.write:
            save_json(STATE_PATH, state)

    body = report(existing, added, errors, missing_config, state)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            fh.write(body)
    else:
        sys.stdout.write(body)


if __name__ == "__main__":
    main()
