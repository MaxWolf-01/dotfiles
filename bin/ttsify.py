#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "click",
#     "requests",
# ]
# ///
"""
Transform markdown files into TTS-friendly format using OpenRouter API.
Designed to handle large files by chunking at paragraph boundaries.
"""

import os
from pathlib import Path

import click
import requests

DEFAULT_MODEL = "gpt-5-mini"
CHUNK_SIZE = 37500  # ~9k tokens at 4 chars/token


def chunk_text(text: str, max_size: int = CHUNK_SIZE) -> list[str]:
    """Split text into chunks at paragraph boundaries."""
    if len(text) <= max_size:
        return [text]

    chunks = []
    paragraphs = text.split("\n\n")
    current = ""

    for para in paragraphs:
        # Single paragraph too large - split by lines
        if len(para) > max_size:
            for line in para.split("\n"):
                if len(current) + len(line) + 1 > max_size:
                    if current:
                        chunks.append(current)
                    current = line
                else:
                    current += ("\n" if current else "") + line
        # Add paragraph to current chunk
        elif len(current) + len(para) + 2 > max_size:
            if current:
                chunks.append(current)
            current = para
        else:
            current += ("\n\n" if current else "") + para

    if current:
        chunks.append(current)

    return chunks


def process_chunk(chunk: str, model: str, api_key: str, headers: dict, system_prompt: str) -> str:
    """Send chunk to OpenRouter and return processed text."""

    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": f"Transform the following markdown into TTS-friendly markdown.\n\n<SOURCE_MARKDOWN>\n{chunk}\n</SOURCE_MARKDOWN>",
            },
        ],
    }

    resp = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers=headers,
        json=payload,
        timeout=300,
    )

    if resp.status_code != 200:
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        raise click.ClickException(f"OpenRouter error {resp.status_code}: {detail}")

    try:
        data = resp.json()
        return data["choices"][0]["message"]["content"].strip()
    except Exception as e:
        # Debug output
        debug_file = Path("/tmp/ttsify2_debug.txt")
        debug_file.write_text(
            f"Status: {resp.status_code}\n"
            f"Content-Type: {resp.headers.get('Content-Type', 'unknown')}\n"
            f"Body length: {len(resp.text)}\n\n"
            f"Body:\n{resp.text[:2000]}"
        )
        raise click.ClickException(f"Failed to parse response: {e}\nDebug saved to {debug_file}")


@click.command()
@click.argument("input_path", type=click.Path(exists=True, path_type=Path))
@click.option("--output", "-o", type=click.Path(path_type=Path), help="Output file")
@click.option("--model", "-m", default=DEFAULT_MODEL, help="Model to use")
def main(input_path: Path, output: Path | None, model: str):
    """Transform markdown to TTS-friendly format."""

    # Get API key
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise click.ClickException("OPENROUTER_API_KEY not set")

    # Resolve input
    click.echo("[ttsify] Resolving input...", err=True)
    if input_path.is_dir():
        readme = input_path / "README.md"
        if not readme.exists():
            raise click.ClickException(f"No README.md in {input_path}")
        input_path = readme

    click.echo(f"[ttsify] Reading: {input_path}", err=True)
    text = input_path.read_text(encoding="utf-8")

    # Chunk if needed
    chunks = chunk_text(text)
    if len(chunks) > 1:
        click.echo(f"[ttsify] Input is large, splitting into {len(chunks)} chunks", err=True)

    # Resolve output
    if output is None:
        output = input_path.with_name("TTS.md")
    click.echo(f"[ttsify] Will write to: {output}", err=True)

    # System prompt
    default_rules = (
        "You are a technical editor producing TTS-friendly markdown from academic papers.\n"
        "Rewrite the input into a clear, linear narration optimized for listening.\n"
        "Rules:\n"
        "- Preserve the paper's structure (title, sections) and content (same sentences, same wording) exactly, but ensure smooth narration.\n"
        "- Replace formulas with spoken descriptions (e.g., 'x squared plus y'). \n"
        "- Omit complex tables and equations (but mention their presence e.g. 'Table 1 shows...', 'Equation 2 defines...').\n"
        "- Keep figure captions, but remove markdown image links like ![img-0.jpeg](long-unnecessary-link-to-an-image.jpeg).\n"
        "- Remove citations like '[1][2]', but keep author names if present; turn 'et al.' into 'and colleagues'.\n"
        "- Omit the references section entirely.\n"
        "- Omit metadata (DOI, arXiv ID, publication venue, emails, etc.). This includes repeated headers/footers in the text.\n"
        "- Keep markdown simple (headings, lists, paragraphs).\n"
    )
    system_prompt = default_rules

    click.echo(f"[ttsify] Model: {model}", err=True)

    # Prepare headers
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if referer := os.getenv("OPENROUTER_REFERER") or os.getenv("HTTP_REFERER"):
        headers["HTTP-Referer"] = referer
    if title := os.getenv("OPENROUTER_TITLE"):
        headers["X-Title"] = title

    # Process chunks
    results = []
    for i, chunk in enumerate(chunks, 1):
        if len(chunks) > 1:
            click.echo(f"[ttsify] Processing chunk {i}/{len(chunks)}...", err=True)
        else:
            click.echo("[ttsify] Sending request to OpenRouter...", err=True)

        result = process_chunk(chunk, model, api_key, headers, system_prompt)
        results.append(result)

        if len(chunks) == 1:
            click.echo("[ttsify] Parsing response...", err=True)

    # Write output
    click.echo("[ttsify] Writing output...", err=True)
    final = "\n\n".join(results)
    output.write_text(final, encoding="utf-8")
    click.echo("[ttsify] Done.", err=True)
    # Print output path to stdout for chaining
    click.echo(str(output))


if __name__ == "__main__":
    main()
