#!/usr/bin/env python3
import json
import os
import re
import sys
from html.parser import HTMLParser
from urllib.parse import urlparse
from xml.etree import ElementTree


class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []
        self.canonical_urls = []
        self.ld_json_blocks = []
        self._in_ld_json = False
        self._current_ld_json = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "link":
            rel = attrs.get("rel", "")
            href = attrs.get("href")
            if href and "canonical" in rel.lower().split():
                self.canonical_urls.append(href)
        if tag in {"a", "link", "script"}:
          for key in ("href", "src"):
            value = attrs.get(key)
            if value:
              self.urls.append(value)
        if tag == "script" and attrs.get("type") == "application/ld+json":
            self._in_ld_json = True
            self._current_ld_json = []

    def handle_data(self, data):
        if self._in_ld_json:
            self._current_ld_json.append(data)

    def handle_endtag(self, tag):
        if tag == "script" and self._in_ld_json:
            self.ld_json_blocks.append("".join(self._current_ld_json))
            self._in_ld_json = False
            self._current_ld_json = []


def route_from_path(public_dir, full_path):
    rel = os.path.relpath(full_path, public_dir).replace(os.sep, "/")
    if rel == "index.html":
        return {"/"}
    if rel.endswith("/index.html"):
        base = "/" + rel[: -len("/index.html")]
        return {base, base + "/"}
    if rel.endswith(".html"):
        return {"/" + rel[:-5]}
    return {"/" + rel}


def collect_valid_routes(public_dir):
    valid = set()
    for root, _, files in os.walk(public_dir):
        for name in files:
            full_path = os.path.join(root, name)
            valid.update(route_from_path(public_dir, full_path))
    return valid


def is_redirect_prone_directory_url(path, valid_routes):
    return (
        path != "/"
        and path.endswith("/")
        and path.rstrip("/") in valid_routes
    )


def flatten_jsonld(value):
    if isinstance(value, dict):
        for key, subvalue in value.items():
            if key in {"target", "url", "contentUrl"} and isinstance(subvalue, str):
                yield subvalue
            yield from flatten_jsonld(subvalue)
    elif isinstance(value, list):
        for item in value:
            yield from flatten_jsonld(item)


def normalize_internal(raw, allowed_host):
    if not raw:
        return None
    if raw.startswith("mailto:") or raw.startswith("tel:") or raw.startswith("javascript:"):
        return None
    if raw.startswith("http://") or raw.startswith("https://"):
        parsed = urlparse(raw)
        if parsed.netloc != allowed_host:
            return None
        return (parsed.path or "/").split("?", 1)[0].split("#", 1)[0]
    if raw.startswith("/") and not raw.startswith("//"):
        return raw.split("?", 1)[0].split("#", 1)[0]
    return None


def main():
    public_dir = sys.argv[1]
    allowed_host = sys.argv[2]
    valid_routes = collect_valid_routes(public_dir)
    missing = {}
    redirect_prone = {}
    suspicious_schema = []

    for root, _, files in os.walk(public_dir):
        for name in files:
            if not name.endswith(".html"):
                continue
            full_path = os.path.join(root, name)
            rel = os.path.relpath(full_path, public_dir).replace(os.sep, "/")
            parser = LinkParser()
            with open(full_path, "r", encoding="utf-8") as handle:
                parser.feed(handle.read())

            for raw in parser.urls:
                url = normalize_internal(raw, allowed_host)
                if not url:
                    continue
                if "{" in url or "}" in url:
                    suspicious_schema.append((rel, raw))
                    continue
                if is_redirect_prone_directory_url(url, valid_routes):
                    redirect_prone.setdefault(url, []).append(rel)
                    continue
                if url not in valid_routes:
                    missing.setdefault(url, []).append(rel)

            for raw in parser.canonical_urls:
                url = normalize_internal(raw, allowed_host)
                if url and is_redirect_prone_directory_url(url, valid_routes):
                    redirect_prone.setdefault(url, []).append(f"{rel} canonical")

            for block in parser.ld_json_blocks:
                try:
                    payload = json.loads(block)
                except Exception:
                    continue
                for raw in flatten_jsonld(payload):
                    url = normalize_internal(raw, allowed_host)
                    if not url:
                        continue
                    if "{" in url or "}" in url:
                        suspicious_schema.append((rel, raw))
                    elif is_redirect_prone_directory_url(url, valid_routes):
                        redirect_prone.setdefault(url, []).append(f"{rel} json-ld")
                    elif url not in valid_routes:
                        missing.setdefault(url, []).append(rel)

    sitemap_path = os.path.join(public_dir, "sitemap.xml")
    if os.path.exists(sitemap_path):
        try:
            tree = ElementTree.parse(sitemap_path)
            root = tree.getroot()
            namespace = ""
            if root.tag.startswith("{"):
                namespace = root.tag.split("}", 1)[0] + "}"
            for loc in root.findall(f".//{namespace}loc"):
                raw = (loc.text or "").strip()
                url = normalize_internal(raw, allowed_host)
                if url and is_redirect_prone_directory_url(url, valid_routes):
                    redirect_prone.setdefault(url, []).append("sitemap.xml")
        except Exception as exc:
            suspicious_schema.append(("sitemap.xml", f"unparseable sitemap: {exc}"))

    if not missing and not suspicious_schema and not redirect_prone:
        print("OK")
        return

    print("BROKEN")
    if redirect_prone:
        print("## URLs internas/canónicas que redirigen por barra final")
        for url, refs in sorted(redirect_prone.items()):
            sample = ", ".join(sorted(set(refs))[:5])
            print(f"- {url} <- {sample}")
    if missing:
        print("## URLs internas sin destino publicado")
        for url, refs in sorted(missing.items()):
            sample = ", ".join(sorted(set(refs))[:5])
            print(f"- {url} <- {sample}")
    if suspicious_schema:
        print("## URLs declaradas con placeholders o destino dudoso")
        for rel, raw in suspicious_schema[:20]:
            print(f"- {raw} <- {rel}")


if __name__ == "__main__":
    main()
