"""Independent UTF-8 mojibake scan for the Wallforge repo.

Written for Phase 7 Part A. Deliberately does NOT reuse the Phase 6 scan's
logic: it decodes strictly, scans a wider character class, excludes the
read-only Stitch reference folder, and prints the offending line with escapes so
the console cannot hide the evidence behind its own encoding.

Every string in this file is pure ASCII on purpose. Marker *keys* are written
as ``\\uXXXX`` escapes, and no description reproduces the offending characters
literally -- otherwise the scanner would flag its own source and could never
report zero, which would make it useless as a gate.

Usage: python tool/encoding/scan_mojibake.py [--list-only]
"""
import subprocess
import sys
from pathlib import Path

TEXT_EXT = (".md", ".dart", ".py", ".yaml", ".yml", ".json", ".html")
EXCLUDE_DIRS = ("stitch_wallforge_ui_design_system", "build", ".dart_tool")

# (marker, ascii description). The descriptions name code points rather than
# printing the characters, so this file stays scannable by itself.
MARKERS = (
    ("\u00e2\u0080", "U+00E2 U+0080 lead pair (E-family)"),
    ("\u00e2\u201a", "U+00E2 U+201A (quotation/dash family)"),
    ("\u00e2\u20ac", "U+00E2 U+20AC lead pair (truncated sequence)"),
    ("\u00c2\u00a7", "U+00C2 U+00A7 (mis-encoded section sign)"),
    ("\u00c2\u00b0", "U+00C2 U+00B0 (mis-encoded degree sign)"),
    ("\u00c2\u00b1", "U+00C2 U+00B1 (mis-encoded plus-minus)"),
    ("\u00c2\u00a0", "U+00C2 U+00A0 (mis-encoded no-break space)"),
    ("\u00c3", "U+00C3 (UTF-8 lead byte read as Latin-1)"),
    ("\u00e2\u0080\u0093", "U+00E2 U+0080 U+0093 (en dash)"),
    ("\u00e2\u0080\u0094", "U+00E2 U+0080 U+0094 (em dash)"),
    ("\u00e2\u0080\u0099", "U+00E2 U+0080 U+0099 (right single quote)"),
    ("\u00e2\u0080\u009c", "U+00E2 U+0080 U+009C (left double quote)"),
    ("\u00e2\u0080\u009d", "U+00E2 U+0080 U+009D (right double quote)"),
    ("\ufffd", "U+FFFD replacement character (lossy decode)"),
)


def tracked_text_files():
    out = subprocess.run(
        ["git", "ls-files"], capture_output=True, text=True, check=True
    ).stdout.split()
    for name in out:
        if not name.endswith(TEXT_EXT):
            continue
        if any(name.startswith(d) or f"/{d}/" in name for d in EXCLUDE_DIRS):
            continue
        yield name


def main():
    list_only = "--list-only" in sys.argv
    problems = []
    scanned = 0

    for name in tracked_text_files():
        scanned += 1
        raw = Path(name).read_bytes()
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            problems.append((name, -1, [f"NOT VALID UTF-8: {exc}"]))
            continue
        for lineno, line in enumerate(text.split("\n"), start=1):
            hits = [desc for marker, desc in MARKERS if marker in line]
            if hits:
                problems.append((name, lineno, [line.strip(), "; ".join(hits)]))

    if list_only:
        for name, _, _ in problems:
            print(name)
        print(f"FILES_WITH_MOJIBAKE={len({p[0] for p in problems})}")
        return 0 if not problems else 1

    print(
        f"scanned {scanned} tracked text files "
        f"(excluding {', '.join(EXCLUDE_DIRS)})"
    )
    if not problems:
        print("RESULT: 0 files with mojibake")
        return 0
    for name, lineno, lines in problems:
        print(f"\n{name}:{lineno}")
        for entry in lines:
            print(f"    {ascii(entry)}")
    print(f"\nFILES_WITH_MOJIBAKE={len({p[0] for p in problems})}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
