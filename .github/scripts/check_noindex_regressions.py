#!/usr/bin/env python3
import argparse
from html.parser import HTMLParser
from pathlib import Path


class RobotsParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.robots = ""

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta" and attrs.get("name", "").lower() == "robots":
            self.robots = attrs.get("content", "")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("public_dir")
    parser.add_argument(
        "--allow",
        action="append",
        default=[],
        help="relative HTML file allowed to contain noindex",
    )
    args = parser.parse_args()

    public_dir = Path(args.public_dir)
    allowed = {Path(item) for item in args.allow}
    failures = []

    for html_file in sorted(public_dir.rglob("*.html")):
        relative = html_file.relative_to(public_dir)
        if relative in allowed:
            continue
        page = RobotsParser()
        page.feed(html_file.read_text(encoding="utf-8", errors="ignore"))
        if "noindex" in page.robots.lower():
            failures.append(str(relative))

    if failures:
        print("Unexpected noindex meta found:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"OK: no unexpected noindex meta tags under {public_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
