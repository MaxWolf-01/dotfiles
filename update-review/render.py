#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["markdown>=3.7"]
# ///
"""Render an update review's verdict (verdict.schema.json) as its report page, in the house style.

Usage: render.py VERDICT_JSON DATE > report.html

The house tokens (tokens.css beside this file) are inlined, so the page stands alone; the fonts stay a link.
"""

import html
import json
import sys
from pathlib import Path

import markdown

HERE = Path(__file__).parent

# The kinds a change can be, in the order the page lists them, each with its Flexoki 2.0 hue,
# day step 600 and night step 400, at half chroma (the house style's rule for a colour the tokens lack).
KINDS = {
    "security": ("Security", "#AF3029", "#D14D41"),
    "breaking": ("Breaking", "#BC5215", "#DA702C"),
    "feature": ("Feature", "#5E409D", "#8B7EC8"),
    "performance": ("Speed", "#24837B", "#3AA99F"),
    "fix": ("Fix", "#205EA6", "#4385BE"),
    "routine": ("Routine", None, None),
}
LEVELS = {
    "critical": ("Critical", "security"),
    "held": ("Held for you", "breaking"),
    "promising": ("Promising", "feature"),
    "routine": ("Routine", "routine"),
}


def md(text: str, inline: bool = False) -> str:
    out = markdown.markdown(text or "", extensions=["tables", "sane_lists"])
    return out.removeprefix("<p>").removesuffix("</p>") if inline and out.count("<p>") == 1 else out


def esc(text: str) -> str:
    return html.escape(text or "")


def kind_css() -> str:
    rules = []
    for kind, (_, day, night) in KINDS.items():
        colour = (f"light-dark(oklch(from {day} l calc(c / 2) h), oklch(from {night} l calc(c / 2) h))"
                  if day else "var(--muted)")
        rules.append(f".k-{kind} {{ --k: {colour}; }}")
    return "\n".join(rules)


def pill(kind: str, label: str | None = None) -> str:
    return f'<span class="pill k-{kind}">{esc(label or KINDS[kind][0])}</span>'


def version(change: dict) -> str:
    old, new = change.get("from", ""), change.get("to", "")
    if not old and not new:
        return ""
    if old and new:
        return f'<span class="v-num">{esc(old)}</span> <span class="arrow">→</span> <span class="v-num">{esc(new)}</span>'
    return f'<span class="v-num">{esc(new or old)}</span> <span class="muted">{"new" if new else "removed"}</span>'


def change_row(change: dict) -> str:
    kind = change["kind"] if change["kind"] in KINDS else "routine"
    source = (f'<a class="source" href="{esc(change["source"])}">source</a>' if change.get("source") else "")
    hosts = "".join(f'<span class="host">{esc(h)}</span>' for h in change.get("hosts", []))
    return f"""
<tr class="k-{kind}">
  <td class="c-kind">{pill(kind)}</td>
  <td class="c-pkg"><div class="pkg">{esc(change["package"])}</div><div class="ver">{version(change)}</div></td>
  <td class="c-what"><div class="title">{esc(change["title"])}</div><div class="detail">{md(change["detail"])}</div>{source}</td>
  <td class="c-hosts">{hosts}</td>
</tr>"""


def counts(changes: list[dict]) -> str:
    seen = [c["kind"] for c in changes]
    return "".join(f'<span class="count k-{k}">{pill(k)} <span class="v-num">{seen.count(k)}</span></span>'
                   for k in KINDS if k in seen)


def host_rows(hosts: list[dict]) -> str:
    return "".join(
        f'<tr><td>{esc(h["host"])}</td><td class="v-num">{h["version_changes"]}</td>'
        f'<td class="v-num">{h.get("added", 0)}</td><td class="v-num">{h.get("removed", 0)}</td>'
        f'<td class="v-num">{esc(h["closure"])}</td></tr>' for h in hosts)


def page(v: dict, date: str) -> str:
    label, level_kind = LEVELS.get(v["level"], ("Unknown", "routine"))
    order = list(KINDS)
    changes = sorted(v.get("changes", []), key=lambda c: order.index(c["kind"]) if c["kind"] in KINDS else len(order))
    held = f'<section class="held k-breaking"><h2>Why it waits</h2>{md(v["held_because"])}</section>' if v.get("held_because") else ""
    notes = f'<section><h2>Also worth knowing</h2><div class="prose">{md(v["notes"])}</div></section>' if v.get("notes") else ""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Update review {esc(date)}: {esc(label)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400;1,6..72,600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
{(HERE / "tokens.css").read_text()}
{kind_css()}
{(HERE / "report.css").read_text()}
</style>
<script>
const theme = new URLSearchParams(location.search).get('theme');
if (theme === 'day' || theme === 'night') document.documentElement.dataset.theme = theme;
</script>
</head>
<body>
<main>
<header class="k-{level_kind}">
  <p class="v-meta">Update review · {esc(date)}</p>
  <h1 class="v-title"><span class="level">{esc(label)}</span></h1>
  <p class="headline">{esc(v["headline"])}</p>
  <div class="summary">{md(v["summary"])}</div>
  <div class="counts">{counts(changes)}</div>
</header>
{held}
<section>
<h2>What changed</h2>
<table class="changes">
<thead><tr><th>Kind</th><th>Package</th><th>What it means</th><th>Hosts</th></tr></thead>
<tbody>{"".join(change_row(c) for c in changes) or '<tr><td colspan="4" class="muted">Nothing moved that a host runs.</td></tr>'}</tbody>
</table>
</section>
<section>
<h2>Per host</h2>
<table class="hosts">
<thead><tr><th>Host</th><th>Versions changed</th><th>Added</th><th>Removed</th><th>Closure</th></tr></thead>
<tbody>{host_rows(v.get("hosts", []))}</tbody>
</table>
</section>
{notes}
<footer class="v-meta">Apply it to every host with <code>update-review apply</code>, or drop it with <code>update-review dismiss</code>.</footer>
</main>
</body>
</html>
"""


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(0 if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help") else 2)
    sys.stdout.write(page(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2]))
