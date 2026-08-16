#!/usr/bin/env python3
"""Turns one version's CHANGELOG section into the HTML Sparkle shows in the
update dialog. Usage: changelog_to_html.py 2.1.0"""

import html
import re
import sys


def section(version):
    lines = []
    marker = "## [%s]" % version
    found = False
    with open("CHANGELOG.md", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith(marker):
                found = True
                continue
            if found and line.startswith("## ["):
                break
            if found:
                lines.append(line.rstrip("\n"))
    return lines


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)


def main():
    version = sys.argv[1]
    out = [
        "<html><head><meta charset='utf-8'><style>",
        "body{font:13px -apple-system,sans-serif;margin:12px;line-height:1.5}",
        "h2{font-size:13px;margin:14px 0 4px;text-transform:uppercase;",
        "letter-spacing:.04em;opacity:.6}",
        "ul{margin:0 0 8px 18px;padding:0}li{margin:3px 0}",
        "code{font:11px ui-monospace,monospace;background:rgba(127,127,127,.15);",
        "padding:1px 4px;border-radius:3px}",
        "</style></head><body>",
    ]

    open_list = False
    for line in section(version):
        stripped = line.strip()
        if stripped.startswith("### "):
            if open_list:
                out.append("</ul>")
                open_list = False
            out.append("<h2>%s</h2>" % inline(stripped[4:]))
        elif stripped.startswith("- "):
            if not open_list:
                out.append("<ul>")
                open_list = True
            out.append("<li>%s</li>" % inline(stripped[2:]))
        elif stripped and open_list:
            out[-1] = out[-1][:-len("</li>")] + " " + inline(stripped) + "</li>"
        elif stripped:
            out.append("<p>%s</p>" % inline(stripped))

    if open_list:
        out.append("</ul>")
    out.append("</body></html>")
    print("\n".join(out))


if __name__ == "__main__":
    main()
