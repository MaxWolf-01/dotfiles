#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "click",
#   "requests",
# ]
# ///

import os
import json
from pathlib import Path
from typing import Optional

import click
import requests


DEFAULT_MODEL = "gpt-5-mini"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def resolve_input_file(input_path: Path) -> Path:
    if input_path.is_dir():
        candidate = input_path / "README.md"
        if not candidate.exists():
            raise click.ClickException(f"Directory has no README.md: {input_path}")
        return candidate
    if not input_path.exists():
        raise click.ClickException(f"File not found: {input_path}")
    return input_path


def build_prompt(default_rules: str, extra_prompt: Optional[str]) -> str:
    if extra_prompt:
        return default_rules.strip() + "\n\nUser Additional Instructions:\n" + extra_prompt.strip()
    return default_rules


@click.command()
@click.argument("input_path", type=click.Path(path_type=Path))
@click.option("--output", "output_path", type=click.Path(path_type=Path), default=None,
              help="Output file path (default: sibling TTS.md)")
@click.option("--model", default=DEFAULT_MODEL, show_default=True,
              help="OpenRouter model ID to use")
@click.option("--api-key", envvar="OPENROUTER_API_KEY", default=None,
              help="OpenRouter API key (or set OPENROUTER_API_KEY)")
@click.option("--prompt-file", type=click.Path(path_type=Path), default=None,
              help="Optional file with extra TTS transformation instructions")
@click.option("--prompt", "extra_prompt", default=None,
              help="Optional inline extra instructions (overrides --prompt-file)")
def main(input_path: Path, output_path: Optional[Path], model: str, api_key: Optional[str],
         prompt_file: Optional[Path], extra_prompt: Optional[str]):
    """Convert README.md into a TTS-friendly TTS.md using OpenRouter.

    INPUT_PATH can be a README.md file or a directory containing README.md.
    """
    if not api_key:
        raise click.ClickException(
            "Missing OpenRouter API key. Provide --api-key or set OPENROUTER_API_KEY."
        )

    click.echo("[ttsify] Resolving input...", err=True)
    readme_path = resolve_input_file(input_path)
    click.echo(f"[ttsify] Reading: {readme_path}", err=True)
    src_md = read_text(readme_path)

    # Determine output path
    if output_path is None:
        output_path = readme_path.with_name("TTS.md")
    click.echo(f"[ttsify] Will write to: {output_path}", err=True)

    # Load extra prompt
    if extra_prompt is None and prompt_file is not None:
        extra_prompt = read_text(prompt_file)

    # Default TTS transformation rules
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
        "- Omit metadata (DOI, arXiv ID, publication venue, emails, etc.).\n"
        "- Keep markdown simple (headings, lists, paragraphs).\n"
    )

    system_prompt = build_prompt(default_rules, extra_prompt)
    click.echo(f"[ttsify] Model: {model}", err=True)

    # Prepare OpenRouter request
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    # Optional attribution headers
    referer = os.getenv("OPENROUTER_REFERER") or os.getenv("HTTP_REFERER")
    title = os.getenv("OPENROUTER_TITLE")
    if referer:
        headers["HTTP-Referer"] = referer
    if title:
        headers["X-Title"] = title

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": (
                    "Transform the following markdown into TTS-friendly markdown.\n\n"
                    "<SOURCE_MARKDOWN>\n" + src_md + "\n</SOURCE_MARKDOWN>\n"
                ),
            },
        ],
    }

    try:
        click.echo("[ttsify] Sending request to OpenRouter...", err=True)
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=120)
    except Exception as e:
        raise click.ClickException(f"OpenRouter request failed to send: {e}")

    if resp.status_code != 200:
        # Try to include model/provider error if present
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        raise click.ClickException(
            f"OpenRouter error {resp.status_code}: {detail}"
        )

    try:
        click.echo("[ttsify] Parsing response...", err=True)
        data = resp.json()
        content = data["choices"][0]["message"]["content"].strip()
    except Exception as e:
        raise click.ClickException(f"Failed to parse OpenRouter response: {e}")

    # Write TTS.md
    click.echo("[ttsify] Writing output...", err=True)
    output_path.write_text(content, encoding="utf-8")
    click.echo("[ttsify] Done.", err=True)
    # Only stdout prints the path for chaining
    click.echo(str(output_path))


if __name__ == "__main__":
    main()
