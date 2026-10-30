#!/usr/bin/env python3.12
"""Generate character voice lines for the game from your own text.

Each character has a preset: a macOS `say` base voice plus a light ffmpeg effect
chain that shapes it into that character. No account, no API key, no cost. The
voices are original (a system voice we process), not copies of anyone.

Characters:
    mr_p              Composed, authoritative, menacing-but-approachable; slow,
                      drawn-out delivery with a touch of warm room reverb.
    program_manager   Brisk, upbeat, confident team leader; quick and clear, dry.

Examples:
    python3.12 tools/mr_p_voice.py "So... you've finally arrived."
    python3.12 tools/mr_p_voice.py -c program_manager "All right, people, let's go."
    python3.12 tools/mr_p_voice.py -c program_manager "Welcome aboard." --out welcome
    python3.12 tools/mr_p_voice.py --file tools/mr_p_lines.txt
    python3.12 tools/mr_p_voice.py "Try again." --no-play

Generated audio lands in godot/assets/audio/<character>/ as .wav files Godot can play.
"""
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO_ROOT = ROOT / "godot" / "assets" / "audio"

# --- Character voice presets --------------------------------------------------
# Tweak any value to redirect a character; each field is explained below.
#   voice   : macOS `say` base voice (see `say -v '?'`)
#   wpm     : speaking rate; lower = slower/more deliberate, higher = brisker
#   pitch   : <1 deepens, >1 lifts; stay near 1.0 to keep it natural
#   tempo   : 1.0 keeps the pitch shift's length (more drag); >1 tightens it up
#   bass    : dB of low-end warmth (+ fuller, - thinner)
#   treble  : dB of top end (+ crisper/clearer, - softer)
#   echo    : light room reverb "in:out:delay_ms:decay", or None for a dry voice
#   folder  : subfolder under godot/assets/audio/ for this character's lines
CHARACTERS = {
    "mr_p": {
        "voice": "Ralph",     # deep, gravelly AMERICAN male (no UK accent)
        "wpm": 118,           # slower = more of the natural drawl/drag she wanted
        "pitch": 1.0,         # lightened up from 0.97 so he's not quite so deep
        "tempo": 1.0,
        "bass": 3,
        "treble": -2,
        "echo": "0.8:0.85:60:0.14",
        "folder": "mrp",
        "peak": 0.68,         # quieter, gentler level (was blasting before)
        "pause_ms": 320,      # natural beat inserted between his sentences
        "ellipsis_ms": 600,   # longer beat wherever you type "..."
    },
    "program_manager": {
        "voice": "Samantha",
        "wpm": 185,
        "pitch": 1.07,         # lifted well above 1.0 = brighter, less low/robotic
        "tempo": 0.93,         # ~1/pitch so only the pitch lifts, not the speed
        "bass": 1,
        "treble": 2,           # extra presence/clarity so she sounds crisp and alive
        "echo": None,          # dry and direct = in-the-room leadership energy
        "folder": "pm",
        "pause_ms": 0,         # leave the PM's pacing natural/unpadded
        "ellipsis_ms": 400,
    },
}
DEFAULT_CHARACTER = "mr_p"


def ffmpeg_filter(preset: dict) -> str:
    """Build the effect chain. Pitch is asetrate (shifts pitch+speed), then
    atempo restores speed so only the pitch stays shifted; the rest is EQ and
    optional light reverb."""
    parts = [
        f"asetrate=22050*{preset['pitch']}",
        "aresample=22050",
        f"atempo={preset['tempo']}",
        f"bass=g={preset['bass']}",
        f"treble=g={preset['treble']}",
    ]
    if preset["echo"]:
        parts.append(f"aecho={preset['echo']}")
    # p is the loudness target peak (0..1): lower = quieter, gentler, less pumping
    parts.append(f"dynaudnorm=f=250:g=7:p={preset.get('peak', 0.95)}")
    return ",".join(parts)


# Abbreviations ending in a period that should NOT trigger a sentence pause.
_ABBREV = {"mr", "mrs", "ms", "dr", "st", "jr", "sr", "vs", "no", "etc"}


def add_pauses(text: str, pause_ms: int, ellipsis_ms: int) -> str:
    """Insert real timed silences for natural delivery: a long beat wherever the
    writer typed '...', and a short beat between sentences (but never after an
    abbreviation like 'Mr.'). macOS `say` reads [[slnc N]] as N ms of silence."""
    if ellipsis_ms:
        text = re.sub(r"\.{3}|…", f" [[slnc {ellipsis_ms}]] ", text)
    if pause_ms:
        def repl(m: re.Match) -> str:
            word, punct = m.group(1), m.group(2)
            if word.lower() in _ABBREV:
                return m.group(0)
            return f"{word}{punct} [[slnc {pause_ms}]] "
        text = re.sub(r"(\w+)([.!?])\s+", repl, text)
    return text


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return (slug[:40] or "line").rstrip("-")


def require(tool: str) -> None:
    if shutil.which(tool) is None:
        sys.exit(f"'{tool}' is not installed. This tool needs macOS `say` and ffmpeg.")


def make_line(text: str, out_name: str, preset: dict, play: bool) -> Path:
    require("say")
    require("ffmpeg")
    out_dir = AUDIO_ROOT / preset["folder"]
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{out_name}.wav"

    spoken = add_pauses(text, preset.get("pause_ms", 0), preset.get("ellipsis_ms", 0))
    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as tmp:
        raw = Path(tmp.name)
    try:
        # 1) macOS speech -> raw AIFF (with natural pause markers)
        subprocess.run(
            ["say", "-v", preset["voice"], "-r", str(preset["wpm"]),
             "-o", str(raw), spoken],
            check=True,
        )
        # 2) apply the character's effect chain -> game-ready WAV
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(raw), "-af", ffmpeg_filter(preset),
             "-ar", "44100", "-ac", "1", str(out_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        raw.unlink(missing_ok=True)

    print(f"  “{text}”\n    -> {out_path}")
    if play and shutil.which("afplay"):
        subprocess.run(["afplay", str(out_path)], check=False)
    return out_path


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("text", nargs="?", help="The line for the character to speak")
    parser.add_argument("-c", "--character", choices=sorted(CHARACTERS),
                        default=DEFAULT_CHARACTER,
                        help=f"Which character's voice to use (default: {DEFAULT_CHARACTER})")
    parser.add_argument("--file", type=Path,
                        help="A text file with one line per row to generate in batch")
    parser.add_argument("--out", help="Output file name (without extension); defaults to a slug of the text")
    parser.add_argument("--no-play", action="store_true", help="Generate without playing it back")
    args = parser.parse_args(argv)

    if not args.text and not args.file:
        parser.error("Give a phrase in quotes, or --file with a list of lines.")

    preset = CHARACTERS[args.character]
    play = not args.no_play
    if args.file:
        lines = [ln.strip() for ln in args.file.read_text(encoding="utf-8").splitlines()
                 if ln.strip() and not ln.strip().startswith("#")]
        if not lines:
            parser.error(f"No lines found in {args.file}")
        print(f"Generating {len(lines)} line(s) for {args.character}:")
        for i, line in enumerate(lines, 1):
            make_line(line, args.out or slugify(line) or f"line-{i}", preset, play)
    else:
        print(f"Generating {args.character}'s line:")
        make_line(args.text, args.out or slugify(args.text), preset, play)
    return 0


if __name__ == "__main__":
    sys.exit(main())
