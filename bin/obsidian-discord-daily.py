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


def split_text(text: str, limit: int = 1900) -> list[str]:
    """Split text into chunks respecting the character limit."""
    if len(text) <= limit:
        return [text]

    chunks = []
    current = ""

    for para in text.split("\n\n"):
        # If paragraph itself exceeds limit, split on single newlines
        if len(para) > limit:
            for line in para.split("\n"):
                # If single line exceeds limit, hard split it
                while len(line) > limit:
                    chunks.append(line[:limit])
                    line = line[limit:]
                if len(current) + len(line) + 1 > limit:
                    if current:
                        chunks.append(current.strip())
                    current = line
                else:
                    current = f"{current}\n{line}" if current else line
        elif len(current) + len(para) + 2 > limit:
            if current:
                chunks.append(current.strip())
            current = para
        else:
            current = f"{current}\n\n{para}" if current else para

    if current:
        chunks.append(current.strip())

    return [c for c in chunks if c]


def post_to_discord(webhook_url: str, content: str) -> None:
    """Post message to Discord webhook, splitting if needed."""
    for chunk in split_text(content):
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
