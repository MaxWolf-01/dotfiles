#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# ///
"""Extract user/assistant text conversation from Claude Code session, excluding tool calls and diffs."""

import argparse
import json
import sys
from pathlib import Path


def extract_text_content(content) -> str:
    """Extract only text content, skipping tool_use, tool_result, thinking blocks."""
    if isinstance(content, str):
        return content

    if not isinstance(content, list):
        return ""

    parts = []
    for item in content:
        if isinstance(item, str):
            parts.append(item)
        elif isinstance(item, dict):
            if item.get("type") == "text":
                parts.append(item.get("text", ""))
            # Skip: tool_use, tool_result, thinking, etc.

    return "\n".join(parts)


def find_session_path(arg: str) -> tuple[Path, str]:
    """Find session file from ID or path. Returns (path, session_id)."""
    # Try as path first
    session_path = Path(arg)
    if session_path.exists():
        return session_path, session_path.stem

    # Try as session ID in current project
    home = Path.home()
    cwd_encoded = Path.cwd().as_posix().replace("/", "-")
    session_path = home / ".claude" / "projects" / cwd_encoded / f"{arg}.jsonl"
    if session_path.exists():
        return session_path, arg

    # Try searching all project folders for the session ID
    projects_dir = home / ".claude" / "projects"
    if projects_dir.exists():
        for project_dir in projects_dir.iterdir():
            if project_dir.is_dir():
                candidate = project_dir / f"{arg}.jsonl"
                if candidate.exists():
                    return candidate, arg

    raise FileNotFoundError(f"Session not found: {arg}")


def extract_conversation(session_path: Path) -> list[tuple[str, str]]:
    """Extract (role, text) pairs from session."""
    messages = []

    for line in session_path.read_text().splitlines():
        if not line.strip():
            continue

        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        entry_type = entry.get("type")
        if entry_type not in ("user", "assistant"):
            continue

        # Skip meta messages (skill expansions, command parsing)
        if entry.get("isMeta"):
            continue

        message = entry.get("message", {})
        role = message.get("role", entry_type)
        content = message.get("content")

        if not content:
            continue

        text = extract_text_content(content).strip()
        if not text:
            continue

        messages.append((role, text))

    return messages


def format_xml(
    messages: list[tuple[str, str]],
    source_path: Path,
    total: int,
    filters: str | None = None,
) -> str:
    """Format messages as XML."""
    attrs = f'source="{source_path}" total="{total}" exported="{len(messages)}"'
    if filters:
        attrs += f' filters="{filters}"'
    lines = [f"<session-export {attrs}>"]

    for role, text in messages:
        lines.append(f"  <{role}>")
        # Indent content
        for content_line in text.split("\n"):
            lines.append(f"    {content_line}" if content_line else "")
        lines.append(f"  </{role}>")

    lines.append("</session-export>")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", help="Session ID or path to .jsonl file")
    parser.add_argument("output", nargs="?", help="Output path (default: ./<session-id>.txt)")
    parser.add_argument("--skip", type=int, default=0, metavar="N", help="Skip first N messages")
    parser.add_argument("--skip-last", type=int, default=0, metavar="N", help="Skip last N messages")
    parser.add_argument("--head", type=int, metavar="N", help="Only first N messages")
    parser.add_argument("--tail", type=int, metavar="N", help="Only last N messages")
    args = parser.parse_args()

    try:
        session_path, session_id = find_session_path(args.session)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    messages = extract_conversation(session_path)
    total = len(messages)

    # Apply filters: skip first, then skip last, then head/tail
    if args.skip:
        messages = messages[args.skip:]
    if args.skip_last:
        messages = messages[:-args.skip_last] if args.skip_last < len(messages) else []
    if args.head:
        messages = messages[: args.head]
    if args.tail:
        messages = messages[-args.tail:]

    # Build filters string for metadata
    filter_parts = []
    if args.skip:
        filter_parts.append(f"--skip {args.skip}")
    if args.skip_last:
        filter_parts.append(f"--skip-last {args.skip_last}")
    if args.head:
        filter_parts.append(f"--head {args.head}")
    if args.tail:
        filter_parts.append(f"--tail {args.tail}")
    filters = " ".join(filter_parts) if filter_parts else None

    output = format_xml(messages, session_path, total, filters)
    output_path = Path(args.output) if args.output else Path.cwd() / f"{session_id}.txt"

    output_path.write_text(output)
    chars = len(output)
    tokens_est = chars // 4  # ~4 chars per token rule of thumb
    print(f"Exported {len(messages)}/{total} messages to {output_path}")
    print(f"  {chars:,} chars, ~{tokens_est:,} tokens")


if __name__ == "__main__":
    main()
