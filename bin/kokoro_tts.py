# /// script
# dependencies = [
#   "kokoro~=0.9.4",
#   "soundfile~=0.13.1",
#   "pip~=25.0.1",
# ]
# ///

"""
Kokoro Text-to-Speech Converter

This script converts text to speech using the Kokoro pipeline and saves the result as a WAV file.
It can read from a file or from stdin and supports various configuration options.
"""

import argparse
import sys
from pathlib import Path

VOICES: str = """
Available voices:
American English (a):
  Female:
    af_heart: Quality: A ❤️
    af_bella: Quality: A- 🔥
    af_nicole: Quality: B- 🎧
    af_aoede: Quality: C+ 
    af_kore: Quality: C+ 
    af_sarah: Quality: C+ 
    af_nova: Quality: C 
    af_alloy: Quality: C 
    af_sky: Quality: C- 
    af_jessica: Quality: D 
    af_river: Quality: D 
  Male:
    am_michael: Quality: C+ 
    am_fenrir: Quality: C+ 
    am_puck: Quality: C+ 
    am_echo: Quality: D 
    am_eric: Quality: D 
    am_liam: Quality: D 
    am_onyx: Quality: D 
    am_santa: Quality: D- 
    am_adam: Quality: F+ 
British English (b):
  Female:
    bf_emma: Quality: B- 
    bf_isabella: Quality: C 
    bf_alice: Quality: D 
    bf_lily: Quality: D 
  Male:
    bm_george: Quality: C 
    bm_fable: Quality: C 
    bm_lewis: Quality: D+ 
    bm_daniel: Quality: D
"""


def main():
    parser = argparse.ArgumentParser(description="Convert text to speech using Kokoro.")
    parser.add_argument(
        "input_file",
        nargs="?",
        help="Input text file (default: ~/Downloads/text if not specified and no stdin)",
    )
    parser.add_argument(
        "-o", "--output", help="Output WAV file (default: kokoro_output.wav)"
    )
    parser.add_argument(
        "-v", "--voice", default="af_heart", help="Voice to use (default: af_heart)"
    )
    parser.add_argument(
        "-r", "--rate", type=int, default=24000, help="Sample rate (default: 24000)"
    )
    parser.add_argument(
        "--voices", action="store_true", help="List available voices and exit"
    )

    args = parser.parse_args()

    if args.voices:
        print(VOICES)
        return

    if not sys.stdin.isatty():  # Data is being piped in
        text = sys.stdin.read()
    elif args.input_file:
        text = Path(args.input_file).read_text()
    else:
        default_file = Path.home() / "Downloads" / "text"
        if default_file.exists():
            text = default_file.read_text()
        else:
            print(f"Error: Default file {default_file} not found and no input provided")
            sys.exit(1)

    if args.output:
        output_file = args.output
    else:
        output_file = Path.home() / "Downloads" / "kokoro_output.wav"

    try:
        from kokoro import KPipeline
        import soundfile as sf
        import numpy as np

        pipeline = KPipeline(repo_id="hexgrad/Kokoro-82M", lang_code=args.voice[0])
        generator = pipeline(text, voice=args.voice)

        all_audio = []
        for i, (gs, ps, audio) in enumerate(generator):
            print(
                f"Processing segment {i}: Generator state: {gs}, Pipeline state: {ps}"
            )
            all_audio.append(audio)

        if all_audio:
            combined_audio = np.concatenate(all_audio)
            sf.write(output_file, combined_audio, args.rate)
            print(f"Output:\n{output_file}")
        else:
            print("Error: No audio segments were generated")
            sys.exit(1)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
