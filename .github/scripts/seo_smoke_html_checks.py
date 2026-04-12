#!/usr/bin/env python3
import json
import os
import sys
from html.parser import HTMLParser
from pathlib import Path


DOMAIN = os.environ["SEO_SMOKE_DOMAIN"]
html = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
html_lower = html.lower()

INTERNAL_COPY_MARKERS = [
    "objetivo cluster-first",
    "si el usuario ya ha mostrado intencion",
    "no distraer",
    "oportunidades de monetizacion",
    "prolonga la sesion",
]


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_title = False
        self.in_h1 = False
        self.in_script = False
        self.current_script_type = ""
        self.title_chunks = []
        self.h1_chunks = []
        self.meta_description = ""
        self.meta_robots = ""
        self.canonical = ""
        self.has_ldjson = False
        self.has_adsense_script = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "title":
            self.in_title = True
        elif tag == "h1":
            self.in_h1 = True
        elif tag == "meta":
            name = attrs.get("name", "").lower()
            if name == "description":
                self.meta_description = attrs.get("content", "")
            elif name == "robots":
                self.meta_robots = attrs.get("content", "")
        elif tag == "link":
            if attrs.get("rel", "").lower() == "canonical":
                self.canonical = attrs.get("href", "")
        elif tag == "script":
            self.in_script = True
            self.current_script_type = attrs.get("type", "").lower()
            src = attrs.get("src", "")
            if "pagead2.googlesyndication.com/pagead/js/adsbygoogle.js" in src and "ca-pub-9368517395014039" in src:
                self.has_adsense_script = True
            if self.current_script_type == "application/ld+json":
                self.has_ldjson = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
        elif tag == "h1":
            self.in_h1 = False
        elif tag == "script":
            self.in_script = False
            self.current_script_type = ""

    def handle_data(self, data):
        if self.in_title:
            self.title_chunks.append(data)
        if self.in_h1:
            self.h1_chunks.append(data)
        if self.in_script and self.current_script_type == "application/ld+json" and data.strip():
            self.has_ldjson = True


parser = PageParser()
parser.feed(html)

title_text = " ".join(chunk.strip() for chunk in parser.title_chunks if chunk.strip()).strip()
h1_text = " ".join(chunk.strip() for chunk in parser.h1_chunks if chunk.strip()).strip()
meta_robots = parser.meta_robots.lower()

results = {
    "title_present": bool(title_text),
    "meta_description_present": bool(parser.meta_description.strip()),
    "canonical_ok": parser.canonical in {f"https://{DOMAIN}", f"https://{DOMAIN}/"},
    "structured_data_present": parser.has_ldjson,
    "adsense_script_present": parser.has_adsense_script,
    "homepage_not_noindex": "noindex" not in meta_robots,
    "h1_present": bool(h1_text),
    "internal_copy_leaked": any(marker in html_lower for marker in INTERNAL_COPY_MARKERS),
}

print(json.dumps(results))
