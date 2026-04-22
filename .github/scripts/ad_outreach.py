#!/usr/bin/env python3
import argparse
import base64
import datetime as dt
import email.utils
import imaplib
import json
import os
import re
import smtplib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(os.environ.get("GITHUB_WORKSPACE", os.getcwd()))
PROSPECTS_PATH = ROOT / "docs" / "AD_PROSPECTS.json"
TEMPLATE_PATH = ROOT / "docs" / "AD_OUTREACH_TEMPLATE.txt"
LEARNING_PATH = ROOT / "docs" / "AD_OUTREACH_LEARNING.json"


def env_int(name, default, minimum=None, maximum=None):
    value = int(os.environ.get(name, str(default)))
    if minimum is not None:
        value = max(value, minimum)
    if maximum is not None:
        value = min(value, maximum)
    return value


FROM_EMAIL = os.environ.get("ASTRO_MAIL_FROM", "publicidad@carta-astral-gratis.es")
FROM_NAME = os.environ.get("ASTRO_MAIL_FROM_NAME", "Astro Cluster")
IMPERSONATE = os.environ.get("WORKSPACE_GMAIL_IMPERSONATE", "info@licitago.es")
SUBJECT = os.environ.get("AD_OUTREACH_SUBJECT", "Propuesta de publicidad directa en Astro Cluster")
CONFIGURED_MAX_SEND = env_int("AD_OUTREACH_MAX_SEND", 2, minimum=0)
HARD_MAX_SEND = env_int("AD_OUTREACH_HARD_MAX_SEND", 2, minimum=0)
MAX_SEND = min(CONFIGURED_MAX_SEND, HARD_MAX_SEND)
SEND_NEW = os.environ.get("AD_OUTREACH_SEND_NEW", "0") == "1"
REQUIRE_SOURCE_EMAIL = os.environ.get("AD_OUTREACH_REQUIRE_SOURCE_EMAIL", "1") == "1"
AUTO_APPROVE_VALIDATED = os.environ.get("AD_OUTREACH_AUTO_APPROVE_VALIDATED", "1") == "1"
REQUIRE_MANUAL_APPROVAL = os.environ.get("AD_OUTREACH_REQUIRE_MANUAL_APPROVAL", "0") == "1"
ALLOW_PUBLIC_PERSONAL_EMAIL = os.environ.get("AD_OUTREACH_ALLOW_PUBLIC_PERSONAL_EMAIL", "1") == "1"
VALIDATION_MAX_AGE_DAYS = env_int("AD_OUTREACH_VALIDATION_MAX_AGE_DAYS", 14, minimum=0)
PAUSE_ON_OPEN_REPLIES = os.environ.get("AD_OUTREACH_PAUSE_ON_OPEN_REPLIES", "1") == "1"
PAUSE_ON_RECENT_BOUNCE = os.environ.get("AD_OUTREACH_PAUSE_ON_RECENT_BOUNCE", "1") == "1"
RECENT_BOUNCE_DAYS = env_int("AD_OUTREACH_RECENT_BOUNCE_DAYS", 7, minimum=1)
RECENT_BOUNCE_PAUSE_MIN = env_int("AD_OUTREACH_RECENT_BOUNCE_PAUSE_MIN", 2, minimum=1)
POST_SEND_BOUNCE_WAIT_SECONDS = env_int("AD_OUTREACH_POST_SEND_BOUNCE_WAIT_SECONDS", 0, minimum=0, maximum=180)
MIN_SENT_FOR_RATE_GUARDRAILS = env_int("AD_OUTREACH_MIN_SENT_FOR_RATE_GUARDRAILS", 10, minimum=1)
MAX_BOUNCE_RATE = float(os.environ.get("AD_OUTREACH_MAX_BOUNCE_RATE", "0.05"))
MAX_NOT_INTERESTED_RATE = float(os.environ.get("AD_OUTREACH_MAX_NOT_INTERESTED_RATE", "0.10"))
MAIL_TRANSPORT = os.environ.get("AD_OUTREACH_MAIL_TRANSPORT", "auto").lower()
SMTP_HOST = os.environ.get("AD_OUTREACH_SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = env_int("AD_OUTREACH_SMTP_PORT", 465, minimum=1)
IMAP_HOST = os.environ.get("AD_OUTREACH_IMAP_HOST", "imap.gmail.com")
GMAIL_USER = os.environ.get("GMAIL_USER", "")
GMAIL_PASS = os.environ.get("GMAIL_PASS", "")

GMAIL_SCOPES = [
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.settings.basic",
]

NEGATIVE_RE = re.compile(r"\b(baja|no me interesa|no interesa|spam|no escribas|eliminar|unsubscribe)\b", re.I)
BOUNCE_USER_UNKNOWN_RE = re.compile(
    r"(5\.1\.1|user doesn't exist|no se ha encontrado la direcci[oó]n|"
    r"recipient address rejected|undeliverable address)",
    re.I,
)
EMAIL_RE = re.compile(r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", re.I)
LOCAL_BLOCKLIST = {
    "abuse", "admin", "billing", "hostmaster", "noreply", "no-reply", "postmaster",
    "privacy", "privacidad", "security", "soporte", "support", "webmaster",
}
PERSONAL_EMAIL_DOMAINS = {
    "gmail.com", "googlemail.com", "hotmail.com", "outlook.com", "live.com",
    "yahoo.com", "yahoo.es", "icloud.com", "me.com", "msn.com", "aol.com",
    "proton.me", "protonmail.com",
}


def b64url(raw):
    if isinstance(raw, str):
        raw = raw.encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def load_json(path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return fallback


def save_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def request(method, url, token=None, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = resp.read().decode("utf-8")
        return json.loads(payload) if payload else {}


def fetch_text(url):
    req = urllib.request.Request(url, headers={"User-Agent": "astro-cluster-outreach/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        content_type = resp.headers.get("Content-Type", "")
        if "text/html" not in content_type and "text/plain" not in content_type:
            return ""
        return resp.read(300_000).decode("utf-8", errors="ignore")


def dns_json(domain, record_type):
    params = urllib.parse.urlencode({"name": domain, "type": record_type})
    return request("GET", f"https://dns.google/resolve?{params}")


def email_domain(email):
    return email.rsplit("@", 1)[1].lower() if "@" in email else ""


def normalize_email(email):
    return (email or "").strip().lower()


def is_personal_email(email):
    return email_domain(email) in PERSONAL_EMAIL_DOMAINS


def source_is_valid_http_url(source_url):
    parsed = urllib.parse.urlparse(source_url or "")
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def parse_datetime(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def validation_is_fresh(prospect):
    validated_at = parse_datetime(prospect.get("validated_at", ""))
    if not validated_at:
        return False
    now = dt.datetime.now(dt.timezone.utc)
    return now - validated_at <= dt.timedelta(days=VALIDATION_MAX_AGE_DAYS)


def needs_validation(prospect):
    if prospect.get("status", "new") not in {"new", "approved", "review_required"}:
        return False
    if prospect.get("validation_status") != "valid":
        return prospect.get("validation_status") in {None, "", "temporary_error", "manual_review"}
    if not validation_is_fresh(prospect):
        return True
    return AUTO_APPROVE_VALIDATED and prospect.get("status") in {"new", "review_required"}


def has_mx(domain):
    payload = dns_json(domain, "MX")
    answers = payload.get("Answer", [])
    return any(answer.get("type") == 15 for answer in answers)


def source_contains_email(prospect):
    source_url = prospect.get("source_url", "")
    email = prospect.get("email", "").lower()
    if not source_url:
        return False
    text = fetch_text(source_url).lower()
    return email in text


def validate_prospect(prospect):
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    previous_validation_status = prospect.get("validation_status")
    previous_validation_reason = prospect.get("validation_reason")
    previous_validated_at = prospect.get("validated_at")
    email = normalize_email(prospect.get("email"))
    prospect["validated_at"] = now

    if not EMAIL_RE.match(email):
        prospect["validation_status"] = "invalid"
        prospect["validation_reason"] = "email_malformed"
        return False

    if REQUIRE_SOURCE_EMAIL and not source_is_valid_http_url(prospect.get("source_url", "")):
        prospect["validation_status"] = "invalid"
        prospect["validation_reason"] = "missing_valid_public_source"
        return False

    local = email.split("@", 1)[0]
    if local in LOCAL_BLOCKLIST:
        prospect["validation_status"] = "invalid"
        prospect["validation_reason"] = "blocked_role_address"
        return False

    domain = email_domain(email)
    try:
        mx_ok = has_mx(domain)
    except Exception as exc:
        reason = f"mx_lookup_failed: {exc}"
        if previous_validation_status == "valid":
            prospect["validated_at"] = previous_validated_at
            prospect["validation_status"] = previous_validation_status
            prospect["validation_reason"] = previous_validation_reason
            prospect["last_validation_error_at"] = now
            prospect["last_validation_error"] = reason
            return validation_is_fresh(prospect)
        prospect["validation_status"] = "temporary_error"
        prospect["validation_reason"] = reason
        return False

    if not mx_ok:
        prospect["validation_status"] = "invalid"
        prospect["validation_reason"] = "domain_without_mx"
        return False

    if REQUIRE_SOURCE_EMAIL:
        try:
            if not source_contains_email(prospect):
                prospect["validation_status"] = "invalid"
                prospect["validation_reason"] = "email_not_visible_on_source"
                return False
        except Exception as exc:
            reason = f"source_check_failed: {exc}"
            if previous_validation_status == "valid":
                prospect["validated_at"] = previous_validated_at
                prospect["validation_status"] = previous_validation_status
                prospect["validation_reason"] = previous_validation_reason
                prospect["last_validation_error_at"] = now
                prospect["last_validation_error"] = reason
                return validation_is_fresh(prospect)
            prospect["validation_status"] = "temporary_error"
            prospect["validation_reason"] = reason
            return False

    if is_personal_email(email) and not (ALLOW_PUBLIC_PERSONAL_EMAIL or prospect.get("allow_personal_email")):
        prospect["validation_status"] = "manual_review"
        prospect["validation_reason"] = "personal_mailbox_requires_explicit_approval"
        if prospect.get("status", "new") == "new":
            prospect["status"] = "review_required"
        return False

    prospect["validation_status"] = "valid"
    prospect["validation_reason"] = (
        "mx_and_public_source_ok_personal_mailbox"
        if is_personal_email(email)
        else "mx_and_public_source_ok"
    )
    if AUTO_APPROVE_VALIDATED and prospect.get("status", "new") in {"new", "review_required"}:
        prospect["status"] = "approved"
        prospect["approved_at"] = now
        prospect["approved_by"] = "automation"
        prospect.pop("review_required_reason", None)
    return True


def service_account_credentials():
    raw = os.environ.get("WORKSPACE_SERVICE_ACCOUNT_JSON", "").strip()
    if raw:
        return json.loads(raw)
    path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    if path:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    raise RuntimeError("Falta WORKSPACE_SERVICE_ACCOUNT_JSON o GOOGLE_APPLICATION_CREDENTIALS")


def access_token():
    import ssl
    del ssl
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    credentials = service_account_credentials()
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}, separators=(",", ":")))
    claim = b64url(json.dumps({
        "iss": credentials["client_email"],
        "scope": " ".join(GMAIL_SCOPES),
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600,
        "sub": IMPERSONATE,
    }, separators=(",", ":")))
    unsigned = f"{header}.{claim}".encode("ascii")
    key = serialization.load_pem_private_key(credentials["private_key"].encode("utf-8"), password=None)
    signature = key.sign(unsigned, padding.PKCS1v15(), hashes.SHA256())
    assertion = f"{unsigned.decode('ascii')}.{b64url(signature)}"
    data = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))["access_token"]
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="ignore")
        try:
            detail = json.loads(payload)
        except ValueError:
            detail = {"error": payload or exc.reason}
        if exc.code in {400, 401, 403}:
            client_id = credentials.get("client_id", "")
            raise RuntimeError(
                "Gmail API DWD no esta autorizado para la service account. "
                f"Autoriza el Client ID {client_id} con los scopes: {', '.join(GMAIL_SCOPES)}. "
                f"Detalle OAuth: {detail}"
            ) from exc
        raise


def encode_header(value):
    return value if all(ord(ch) < 128 for ch in value) else f"=?UTF-8?B?{base64.b64encode(value.encode('utf-8')).decode('ascii')}?="


def active_transport():
    if MAIL_TRANSPORT == "auto":
        if os.environ.get("WORKSPACE_SERVICE_ACCOUNT_JSON", "").strip() or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip():
            return "gmail_api"
        return "smtp" if GMAIL_USER and GMAIL_PASS else "gmail_api"
    return MAIL_TRANSPORT


def build_message_text(to_email, body):
    from_domain = email_domain(FROM_EMAIL) or "carta-astral-gratis.es"
    unsubscribe = f"mailto:{FROM_EMAIL}?subject=Baja%20publicidad"
    message_id = email.utils.make_msgid(domain=from_domain)
    message = "\r\n".join([
        f"From: {encode_header(FROM_NAME)} <{FROM_EMAIL}>",
        f"To: {to_email}",
        f"Reply-To: {FROM_EMAIL}",
        f"Subject: {encode_header(SUBJECT)}",
        f"Date: {email.utils.formatdate(localtime=False, usegmt=True)}",
        f"Message-ID: {message_id}",
        f"List-Unsubscribe: <{unsubscribe}>",
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=UTF-8",
        "",
        body,
    ])
    return message, message_id


def build_message(to_email, body):
    message, _message_id = build_message_text(to_email, body)
    return {"raw": b64url(message)}


def gmail_send(token, to_email, body):
    return request(
        "POST",
        f"https://gmail.googleapis.com/gmail/v1/users/{urllib.parse.quote(IMPERSONATE)}/messages/send",
        token=token,
        body=build_message(to_email, body),
    )


def smtp_send(_token, to_email, body):
    if not GMAIL_USER or not GMAIL_PASS:
        raise RuntimeError("Faltan GMAIL_USER o GMAIL_PASS para transporte SMTP")
    message, message_id = build_message_text(to_email, body)
    with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=30) as client:
        client.login(GMAIL_USER, GMAIL_PASS)
        client.sendmail(FROM_EMAIL, [to_email], message.encode("utf-8"))
    return {"id": message_id, "threadId": ""}


def mail_send(token, to_email, body):
    if active_transport() == "smtp":
        return smtp_send(token, to_email, body)
    return gmail_send(token, to_email, body)


def gmail_list(token, query):
    url = (
        f"https://gmail.googleapis.com/gmail/v1/users/{urllib.parse.quote(IMPERSONATE)}/messages"
        f"?q={urllib.parse.quote(query)}&maxResults=10"
    )
    return request("GET", url, token=token).get("messages", [])


def imap_search(query):
    if not GMAIL_USER or not GMAIL_PASS:
        raise RuntimeError("Faltan GMAIL_USER o GMAIL_PASS para transporte IMAP")
    with imaplib.IMAP4_SSL(IMAP_HOST) as client:
        client.login(GMAIL_USER, GMAIL_PASS)
        client.select("INBOX")
        status, data = client.search(None, "X-GM-RAW", f'"{query}"')
        if status != "OK":
            return []
        ids = data[0].decode("ascii", errors="ignore").split() if data and data[0] else []
        rows = []
        for message_id in ids[:10]:
            fetch_status, fetch_data = client.fetch(message_id, "(BODY.PEEK[HEADER.FIELDS (FROM TO SUBJECT DATE)] BODY.PEEK[TEXT]<0.500>)")
            if fetch_status != "OK":
                continue
            text = " ".join(
                part.decode("utf-8", errors="ignore") if isinstance(part, bytes) else ""
                for item in fetch_data
                if isinstance(item, tuple)
                for part in item
            )
            rows.append({"id": message_id, "snippet": " ".join(text.split())[:500]})
        return rows


def mail_list(token, query):
    if active_transport() == "smtp":
        return imap_search(query)
    return gmail_list(token, query)


def gmail_get(token, message_id):
    url = (
        f"https://gmail.googleapis.com/gmail/v1/users/{urllib.parse.quote(IMPERSONATE)}/messages/"
        f"{urllib.parse.quote(message_id)}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date"
    )
    return request("GET", url, token=token)


def mail_get(token, message_id):
    if active_transport() == "smtp":
        return message_id if isinstance(message_id, dict) else {"id": message_id, "snippet": ""}
    if isinstance(message_id, dict):
        message_id = message_id.get("id", "")
    return gmail_get(token, message_id)


def gmail_send_as(token):
    url = f"https://gmail.googleapis.com/gmail/v1/users/{urllib.parse.quote(IMPERSONATE)}/settings/sendAs"
    return request("GET", url, token=token).get("sendAs", [])


def mailbox_setup(token):
    if active_transport() == "smtp":
        smtp_ok = False
        imap_ok = False
        if GMAIL_USER and GMAIL_PASS:
            with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=30) as client:
                client.login(GMAIL_USER, GMAIL_PASS)
                smtp_ok = True
            with imaplib.IMAP4_SSL(IMAP_HOST) as client:
                client.login(GMAIL_USER, GMAIL_PASS)
                imap_ok = True
        return {
            "transport": "smtp",
            "impersonate": GMAIL_USER or IMPERSONATE,
            "from_email": FROM_EMAIL,
            "from_configured": smtp_ok and imap_ok,
            "from_verification_status": "smtp_imap_login_ok" if smtp_ok and imap_ok else "missing_credentials",
            "send_as": [],
        }
    identities = gmail_send_as(token)
    normalized_from = FROM_EMAIL.lower()
    matching = [
        item for item in identities
        if (item.get("sendAsEmail") or "").lower() == normalized_from
    ]
    return {
        "transport": "gmail_api",
        "impersonate": IMPERSONATE,
        "from_email": FROM_EMAIL,
        "from_configured": bool(matching),
        "from_verification_status": matching[0].get("verificationStatus", "") if matching else "",
        "send_as": [
            {
                "sendAsEmail": item.get("sendAsEmail", ""),
                "displayName": item.get("displayName", ""),
                "isDefault": item.get("isDefault", False),
                "treatAsAlias": item.get("treatAsAlias", False),
                "verificationStatus": item.get("verificationStatus", ""),
            }
            for item in identities
        ],
    }


def assert_mailbox_ready(report):
    if not report["from_configured"]:
        raise RuntimeError(
            f"{FROM_EMAIL} no esta configurado como sendAs en {IMPERSONATE}. "
            "Ejecuta functions-gmail/scripts/workspace-alias.js ensure antes de enviar."
        )
    if report.get("transport") == "smtp":
        return
    status = report.get("from_verification_status")
    if status and status.lower() not in {"accepted", "verified"}:
        raise RuntimeError(
            f"{FROM_EMAIL} existe como sendAs en {IMPERSONATE}, pero su estado es {status}."
        )


def eligible(prospect):
    status = prospect.get("status", "new")
    email = prospect.get("email", "")
    if prospect.get("suppressed_at"):
        return False
    if prospect.get("sent_at"):
        return False
    if prospect.get("validation_status") != "valid":
        return False
    if not validation_is_fresh(prospect):
        return False
    if is_personal_email(email) and not prospect.get("allow_personal_email"):
        if not ALLOW_PUBLIC_PERSONAL_EMAIL:
            return False
    if status == "approved" and REQUIRE_MANUAL_APPROVAL and prospect.get("approved_by") == "automation":
        return False
    return status == "approved" or (SEND_NEW and status == "new")


def open_commercial_replies(prospects):
    return [
        prospect for prospect in prospects
        if prospect.get("status") == "replied"
        and not prospect.get("commercial_followup_at")
        and not prospect.get("closed_at")
    ]


def recent_bounces(prospects):
    threshold = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=RECENT_BOUNCE_DAYS)
    recent = []
    for prospect in prospects:
        if prospect.get("status") != "bounced":
            continue
        bounced_at = parse_datetime(prospect.get("bounced_at", ""))
        if bounced_at and bounced_at >= threshold:
            recent.append(prospect)
    return recent


def outreach_metrics(prospects):
    total_sent = sum(1 for item in prospects if item.get("sent_at"))
    total_replied = sum(1 for item in prospects if item.get("status") == "replied")
    total_negative = sum(1 for item in prospects if item.get("status") == "not_interested")
    total_bounced = sum(1 for item in prospects if item.get("status") == "bounced")
    return {
        "sent": total_sent,
        "replied": total_replied,
        "not_interested": total_negative,
        "bounced": total_bounced,
        "reply_rate": (total_replied / total_sent) if total_sent else 0,
        "not_interested_rate": (total_negative / total_sent) if total_sent else 0,
        "bounce_rate": (total_bounced / total_sent) if total_sent else 0,
    }


def guardrail_decision(prospects):
    metrics = outreach_metrics(prospects)
    reasons = []
    warnings = []
    open_replies = open_commercial_replies(prospects)

    if CONFIGURED_MAX_SEND > HARD_MAX_SEND:
        warnings.append(
            f"AD_OUTREACH_MAX_SEND={CONFIGURED_MAX_SEND} supera el maximo operativo "
            f"{HARD_MAX_SEND}; se aplicara {MAX_SEND}."
        )

    if PAUSE_ON_OPEN_REPLIES and open_replies:
        reasons.append(
            "hay respuestas comerciales abiertas sin commercial_followup_at ni closed_at"
        )

    recent_bounced = recent_bounces(prospects) if PAUSE_ON_RECENT_BOUNCE else []
    if recent_bounced and len(recent_bounced) >= RECENT_BOUNCE_PAUSE_MIN:
        reasons.append(
            f"hay {len(recent_bounced)} rebote(s) reciente(s) en los ultimos {RECENT_BOUNCE_DAYS} dias"
        )
    elif recent_bounced:
        warnings.append(
            f"hay {len(recent_bounced)} rebote(s) reciente(s); se suprime el contacto y se mantiene captacion controlada"
        )

    if metrics["sent"] >= MIN_SENT_FOR_RATE_GUARDRAILS:
        if metrics["bounce_rate"] > MAX_BOUNCE_RATE:
            reasons.append(
                f"tasa de rebote {metrics['bounce_rate']:.1%} superior al umbral {MAX_BOUNCE_RATE:.1%}"
            )
        if metrics["not_interested_rate"] > MAX_NOT_INTERESTED_RATE:
            reasons.append(
                "tasa de no interes "
                f"{metrics['not_interested_rate']:.1%} superior al umbral {MAX_NOT_INTERESTED_RATE:.1%}"
            )

    return {
        "can_send": not reasons,
        "reasons": reasons,
        "warnings": warnings,
        "open_replies": open_replies,
        "metrics": metrics,
    }


def contacted_emails(prospects):
    terminal_statuses = {"sent", "replied", "not_interested", "bounced"}
    return {
        normalize_email(prospect.get("email"))
        for prospect in prospects
        if normalize_email(prospect.get("email"))
        and (
            prospect.get("sent_at")
            or prospect.get("last_contacted_at")
            or prospect.get("message_id")
            or prospect.get("status") in terminal_statuses
        )
    }


def send_batch(token, prospects):
    guardrail = guardrail_decision(prospects)
    if not guardrail["can_send"]:
        return [], [], guardrail
    today = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    body = TEMPLATE_PATH.read_text(encoding="utf-8")
    sent = []
    validated = []
    already_contacted = contacted_emails(prospects)
    for prospect in prospects:
        if len(sent) >= MAX_SEND:
            break
        email = normalize_email(prospect.get("email"))
        if not email or email in already_contacted:
            continue
        before_validation = prospect.get("validation_status")
        before_status = prospect.get("status", "new")
        if needs_validation(prospect):
            validate_prospect(prospect)
            if prospect.get("validation_status") != before_validation or prospect.get("status") != before_status:
                validated.append(prospect)
        if not eligible(prospect):
            continue
        res = mail_send(token, prospect["email"], body)
        prospect["status"] = "sent"
        prospect["sent_at"] = today
        prospect["last_contacted_at"] = today
        prospect["message_id"] = res.get("id", "")
        prospect["thread_id"] = res.get("threadId", "")
        sent.append(prospect)
        already_contacted.add(email)
    return sent, validated, guardrail


def validate_batch(prospects):
    validated = []
    for prospect in prospects:
        if prospect.get("status", "new") not in {"new", "approved", "review_required"}:
            continue
        before_validation = prospect.get("validation_status")
        before_status = prospect.get("status", "new")
        validate_prospect(prospect)
        if prospect.get("validation_status") != before_validation or prospect.get("status") != before_status:
            validated.append(prospect)
    return validated


def mark_bounced(prospect, snippet):
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    reason = "mailbox_bounced_user_unknown" if BOUNCE_USER_UNKNOWN_RE.search(snippet or "") else "mailbox_bounced"
    prospect["status"] = "bounced"
    prospect["bounced_at"] = now
    prospect["suppressed_at"] = now
    prospect["validation_status"] = "invalid"
    prospect["validation_reason"] = reason
    prospect["bounce_snippet"] = (snippet or "")[:240]


def sync_status(token, prospects, restrict_emails=None):
    changed = []
    restrict_emails = {normalize_email(email) for email in restrict_emails or []}
    for prospect in prospects:
        email = prospect.get("email", "")
        normalized_email = normalize_email(email)
        if restrict_emails and normalized_email not in restrict_emails:
            continue
        if not email or prospect.get("status") not in {"sent", "replied", "not_interested", "bounced"}:
            continue
        inbound = mail_list(token, f"from:{email} newer_than:45d")
        if inbound:
            detail = mail_get(token, inbound[0])
            snippet = (detail.get("snippet") or "").strip()
            new_status = "not_interested" if NEGATIVE_RE.search(snippet) else "replied"
            if prospect.get("status") != new_status:
                prospect["status"] = new_status
                prospect["reply_at"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
                prospect["reply_snippet"] = snippet[:240]
                if new_status == "not_interested":
                    prospect["suppressed_at"] = prospect["reply_at"]
                changed.append(prospect)

        bounces = mail_list(token, f"from:(mailer-daemon@googlemail.com OR mailer-daemon@google.com) {email} newer_than:45d")
        if bounces and prospect.get("status") != "bounced":
            detail = mail_get(token, bounces[0])
            mark_bounced(prospect, (detail.get("snippet") or "").strip())
            changed.append(prospect)
    return changed


def build_learning_snapshot(prospects):
    today = dt.date.today().isoformat()
    segments = {}
    def empty_stats():
        return {
            "prospects": 0,
            "approved": 0,
            "sent": 0,
            "replied": 0,
            "not_interested": 0,
            "bounced": 0,
        }

    totals = empty_stats()
    totals["prospects"] = len(prospects)

    for prospect in prospects:
        status = prospect.get("status", "new")
        segment = prospect.get("segment") or "unknown"
        bucket = segments.setdefault(segment, empty_stats())
        bucket["prospects"] += 1
        if status in bucket and status != "sent":
            bucket[status] += 1
        if status in totals and status != "sent":
            totals[status] += 1
        if prospect.get("sent_at"):
            bucket["sent"] += 1
            totals["sent"] += 1

    for bucket in [totals, *segments.values()]:
        sent_count = bucket["sent"]
        bucket["reply_rate"] = round(bucket["replied"] / sent_count, 4) if sent_count else 0
        bucket["not_interested_rate"] = round(bucket["not_interested"] / sent_count, 4) if sent_count else 0
        bucket["bounce_rate"] = round(bucket["bounced"] / sent_count, 4) if sent_count else 0

    action = "continue"
    if PAUSE_ON_RECENT_BOUNCE and len(recent_bounces(prospects)) >= RECENT_BOUNCE_PAUSE_MIN:
        action = "pause_recent_bounce"
    elif totals["sent"] >= MIN_SENT_FOR_RATE_GUARDRAILS and totals["bounce_rate"] > MAX_BOUNCE_RATE:
        action = "pause_high_bounce_rate"
    elif totals["sent"] >= MIN_SENT_FOR_RATE_GUARDRAILS and totals["not_interested_rate"] > MAX_NOT_INTERESTED_RATE:
        action = "reduce_volume_or_adjust_copy"

    return {
        "date": today,
        "daily_send_limit": MAX_SEND,
        "recommended_action": action,
        "totals": totals,
        "segments": dict(sorted(segments.items())),
    }


def save_learning(prospects):
    learning = load_json(LEARNING_PATH, {"version": "1.0", "snapshots": []})
    snapshot = build_learning_snapshot(prospects)
    snapshots = [item for item in learning.get("snapshots", []) if item.get("date") != snapshot["date"]]
    snapshots.append(snapshot)
    learning["snapshots"] = snapshots[-120:]
    learning["updated_at"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    save_json(LEARNING_PATH, learning)
    return snapshot


def render_report(prospects, sent, changed, validated, mailbox_report=None, guardrail=None):
    counts = {}
    for item in prospects:
        counts[item.get("status", "new")] = counts.get(item.get("status", "new"), 0) + 1
    metrics = outreach_metrics(prospects)
    total_sent = metrics["sent"]
    total_replied = metrics["replied"]
    total_negative = metrics["not_interested"]
    total_bounced = metrics["bounced"]
    total_review_required = sum(1 for item in prospects if item.get("status") == "review_required")
    total_auto_approved_blocked = sum(
        1
        for item in prospects
        if item.get("status") == "approved" and item.get("approved_by") == "automation" and REQUIRE_MANUAL_APPROVAL
    )
    reply_rate = metrics["reply_rate"] * 100
    negative_rate = metrics["not_interested_rate"] * 100
    bounce_rate = metrics["bounce_rate"] * 100
    learning_snapshot = build_learning_snapshot(prospects)
    guardrail = guardrail or guardrail_decision(prospects)
    lines = [
        "## Captación de anunciantes",
        "",
        f"- Enviados en esta ejecución: **{len(sent)}**",
        f"- Validados en esta ejecución: **{len(validated)}**",
        f"- Cambios de estado por respuestas/bounces: **{len(changed)}**",
        f"- Límite diario efectivo: **{MAX_SEND}**",
        f"- Límite diario configurado: **{CONFIGURED_MAX_SEND}**",
        f"- Techo operativo anti-abuso: **{HARD_MAX_SEND}**",
        f"- Autoaprobar si validan: **{'sí' if AUTO_APPROVE_VALIDATED else 'no'}**",
        f"- Exigir aprobación manual: **{'sí' if REQUIRE_MANUAL_APPROVAL else 'no'}**",
        f"- Enviar prospectos `new` sin autoaprobar: **{'sí' if SEND_NEW else 'no'}**",
        f"- Exigir email visible en fuente pública: **{'sí' if REQUIRE_SOURCE_EMAIL else 'no'}**",
        f"- Pausar por rebote reciente: **{'sí' if PAUSE_ON_RECENT_BOUNCE else 'no'}**",
        f"- Ventana rebote reciente: **{RECENT_BOUNCE_DAYS} días**",
        f"- Rebotes recientes para pausar: **{RECENT_BOUNCE_PAUSE_MIN}**",
        f"- Espera post-envío para rebotes: **{POST_SEND_BOUNCE_WAIT_SECONDS}s**",
        f"- Transporte email: **{active_transport()}**",
        f"- Usuario Gmail delegado: **{IMPERSONATE}**",
        f"- From comercial: **{FROM_EMAIL}**",
        f"- Pendientes de revisión manual: **{total_review_required}**",
        f"- Aprobados por automatizacion bloqueados: **{total_auto_approved_blocked}**",
        f"- Tasa historica de respuesta positiva: **{reply_rate:.1f}%**",
        f"- Tasa historica de no interes: **{negative_rate:.1f}%**",
        f"- Tasa historica de rebote: **{bounce_rate:.1f}%**",
        f"- Accion recomendada por aprendizaje: **{learning_snapshot['recommended_action']}**",
        f"- Envío permitido por guardarraíles: **{'sí' if guardrail['can_send'] else 'no'}**",
        "",
        "### Estado",
        "",
    ]
    for key in sorted(counts):
        lines.append(f"- `{key}`: {counts[key]}")
    if mailbox_report:
        lines += ["", "### Buzón", ""]
        lines.append(f"- Transporte: `{mailbox_report.get('transport', active_transport())}`")
        lines.append(f"- Usuario delegado: `{mailbox_report['impersonate']}`")
        lines.append(f"- From configurado como sendAs: **{'sí' if mailbox_report['from_configured'] else 'no'}**")
        if mailbox_report.get("from_verification_status"):
            lines.append(f"- Estado sendAs: `{mailbox_report['from_verification_status']}`")
        lines.append(f"- Identidades disponibles: **{len(mailbox_report.get('send_as', []))}**")
    if guardrail.get("warnings"):
        lines += ["", "### Avisos operativos", ""]
        for warning in guardrail["warnings"]:
            lines.append(f"- {warning}")
    if guardrail.get("reasons"):
        lines += ["", "### Envío pausado", ""]
        for reason in guardrail["reasons"]:
            lines.append(f"- {reason}")
    if guardrail.get("open_replies"):
        lines += ["", "### Respuestas abiertas", ""]
        for item in guardrail["open_replies"]:
            lines.append(f"- `{item['email']}` · {item.get('name', '')}")
    if sent:
        lines += ["", "### Enviados", ""]
        for item in sent:
            lines.append(f"- `{item['email']}` · {item.get('name', '')}")
    if validated:
        lines += ["", "### Validación previa", ""]
        for item in validated:
            lines.append(f"- `{item['email']}` · `{item.get('validation_status')}` · {item.get('validation_reason', '')}")
    if changed:
        lines += ["", "### Respuestas o incidencias", ""]
        for item in changed:
            snippet = item.get("reply_snippet", "") or item.get("bounce_snippet", "")
            lines.append(f"- `{item['email']}` · `{item['status']}` · {snippet}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--send", action="store_true")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--check-mailbox", action="store_true")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    prospects = load_json(PROSPECTS_PATH, [])
    needs_mail = args.send or args.sync or args.check_mailbox
    token = access_token() if needs_mail and active_transport() == "gmail_api" else None
    mailbox_report = mailbox_setup(token) if args.send or args.check_mailbox else None
    if args.send:
        assert_mailbox_ready(mailbox_report)
    standalone_validated = validate_batch(prospects) if args.validate else []
    changed = sync_status(token, prospects) if args.sync else []
    if args.send:
        sent, send_validated, guardrail = send_batch(token, prospects)
        if args.sync and sent and POST_SEND_BOUNCE_WAIT_SECONDS:
            time.sleep(POST_SEND_BOUNCE_WAIT_SECONDS)
            sent_emails = {item.get("email", "") for item in sent}
            changed += sync_status(token, prospects, restrict_emails=sent_emails)
            guardrail = guardrail_decision(prospects)
    else:
        sent, send_validated, guardrail = [], [], guardrail_decision(prospects)
    validated = standalone_validated + send_validated
    if args.write and (sent or changed or validated):
        save_json(PROSPECTS_PATH, prospects)
    if args.write:
        save_learning(prospects)
    body = render_report(prospects, sent, changed, validated, mailbox_report, guardrail)
    if args.report:
        Path(args.report).write_text(body, encoding="utf-8")
    else:
        sys.stdout.write(body)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
