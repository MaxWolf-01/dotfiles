#!/usr/bin/env python3
# /// script
# dependencies = ["httpx"]
# ///
"""Post daily notes to Discord via webhook."""

import os
import re
from datetime import date, timedelta
from pathlib import Path

import httpx

VAULT = Path.home() / "repos/obsidian/knowledge-base"
DAILY_NOTES = VAULT / "Obsidian/daily-notes"


def strip_frontmatter(content: str) -> str:
    """Remove YAML frontmatter (content between --- markers at start)."""
    if not content.startswith("---"):
        return content
    match = re.match(r"^---\n.*?\n---\n?", content, re.DOTALL)
    return content[match.end() :] if match else content


def read_note(d: date) -> str | None:
    """Read daily note for given date, return content without frontmatter."""
    path = DAILY_NOTES / f"{d}.md"
    if not path.exists():
        return None
    content = path.read_text()
    return strip_frontmatter(content).strip()


def format_message(today: date, yesterday: date) -> str:
    """Format the Discord message with both days' notes."""
    parts = []

    yesterday_note = read_note(yesterday)
    if yesterday_note:
        parts.append(f"## Yesterday ({yesterday})\n{yesterday_note}")

    today_note = read_note(today)
    if today_note:
        parts.append(f"## Today ({today})\n{today_note}")

    if not parts:
        return "No daily notes found."

    return "\n\n".join(parts)


def post_to_discord(webhook_url: str, content: str) -> None:
    """Post message to Discord webhook, splitting if needed."""
    # Discord limit is 2000 chars
    if len(content) <= 2000:
        resp = httpx.post(webhook_url, json={"content": content})
        resp.raise_for_status()
        return

    # Split on double newlines, respecting the limit
    chunks = []
    current = ""
    for para in content.split("\n\n"):
        if len(current) + len(para) + 2 > 1900:  # Leave some margin
            chunks.append(current.strip())
            current = para
        else:
            current = f"{current}\n\n{para}" if current else para
    if current:
        chunks.append(current.strip())

    for chunk in chunks:
        resp = httpx.post(webhook_url, json={"content": chunk})
        resp.raise_for_status()


def main() -> None:
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
    assert webhook_url, "DISCORD_WEBHOOK_URL not set"

    today = date.today()
    yesterday = today - timedelta(days=1)

    print(f"Posting daily notes for {yesterday} and {today}")
    message = format_message(today, yesterday)
    post_to_discord(webhook_url, message)
    print("Done")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")
        raise
