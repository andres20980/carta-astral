#!/usr/bin/env python3
import argparse
import datetime as dt
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

MAX_NEW = int(os.environ.get("MAX_NEW_PROSPECTS", "10"))
MAX_QUERIES = int(os.environ.get("MAX_SEARCH_QUERIES", "5"))
MAX_RESULTS_PER_QUERY = int(os.environ.get("MAX_RESULTS_PER_QUERY", "5"))
TIMEOUT = int(os.environ.get("PROSPECT_FETCH_TIMEOUT", "12"))

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


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "astro-cluster-prospecting/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


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


def report(existing, added, errors, missing_config):
    lines = [
        "## Prospección diaria de anunciantes",
        "",
        f"- Candidatos nuevos: **{len(added)}**",
        f"- Total histórico: **{len(existing) + len(added)}**",
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
    missing_config = not api_key or not cx

    added = []
    errors = []
    if not missing_config:
        added, errors = prospect(api_key, cx, existing)
        if args.write and added:
            save_json(PROSPECTS_PATH, existing + added)

    body = report(existing, added, errors, missing_config)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            fh.write(body)
    else:
        sys.stdout.write(body)


if __name__ == "__main__":
    main()
