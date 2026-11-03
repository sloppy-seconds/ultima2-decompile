#!/usr/bin/env python3
"""Generate engine/src/core/licenses_data.h from the committed notice files.

Why a generated header rather than reading files at runtime: the whole point of
`--licenses` is that a player holding nothing but the executable can still find
out what is in it. A runtime file lookup would mean shipping extra files, which is
the thing the flag exists to avoid.

Why the output is committed and has no make rule: the same ruling as
engine/content/gen_content.h. A build step that could regenerate this on a machine
missing the inputs would silently ship a shorter list, and a short license list
looks exactly like a complete one. So the build consumes the committed file, and
`make licenses-check` proves it still matches its sources.

Deterministic by construction: no timestamps, fixed entry order, so --verify is a
real comparison and not a diff against a clock.
"""

import argparse
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent          # engine/tools
ENGINE = HERE.parent                                    # engine
REPO = ENGINE.parent

# (title, source file, output filename for the drift report)
ENTRIES = [
    ("This project — Apache License 2.0", REPO / "LICENSE"),
    ("About the game itself — what this binary does and does not contain",
     ENGINE / "licenses" / "game-content-NOTICE.txt"),
    ("SDL3 — zlib licence", ENGINE / "licenses" / "SDL3-LICENSE.txt"),
    ("font8x8 — Public Domain", ENGINE / "licenses" / "font8x8-NOTICE.txt"),
    ("Substitute tile art — Apache-2.0, authored by this project",
     ENGINE / "licenses" / "tile-art-NOTICE.txt"),
]

OUT = ENGINE / "src" / "core" / "licenses_data.h"

GUARD = "U2_CORE_LICENSES_DATA_H"


def c_string(text: str) -> str:
    """Render text as a chain of adjacent C string literals, one per source line.

    Adjacent literals are concatenated by the compiler, which keeps the generated
    header readable and keeps any single line short enough to diff.
    """
    lines = text.split("\n")
    parts = []
    for line in lines:
        esc = line.replace("\\", "\\\\").replace('"', '\\"')
        parts.append('\n    "%s\\n"' % esc)
    return "".join(parts).lstrip("\n")


def build() -> str:
    loaded = []
    for title, path in ENTRIES:
        if not path.is_file():
            raise SystemExit(f"gen_licenses: missing source {path}")
        text = path.read_text(encoding="utf-8").strip("\n")
        if not text.strip():
            # An empty license entry is the failure mode this whole file exists to
            # prevent: a short list that looks complete.
            raise SystemExit(f"gen_licenses: refusing to emit an empty entry for {path}")
        loaded.append((title, path, text))

    out = []
    out.append("/*\n"
               " * licenses_data.h — GENERATED, do not edit.\n"
               " *\n"
               " * Regenerate:  python3 engine/tools/gen_licenses.py\n"
               " * Verify:      make -C engine licenses-check\n"
               " *\n"
               " * The texts come from LICENSE and the notice files under\n"
               " * engine/licenses, all of which are committed, so this file can be\n"
               " * regenerated and checked on a machine that has never seen SDL.\n"
               " * Editing the generated file by hand is the mistake to avoid; edit\n"
               " * the sources and regenerate.\n"
               " */\n")
    out.append(f"#ifndef {GUARD}\n#define {GUARD}\n\n")
    out.append("typedef struct u2_license_entry {\n"
               "    const char *title;   /* one-line heading, printed as-is   */\n"
               "    const char *origin;  /* where the text came from          */\n"
               "    const char *text;    /* the licence or notice, verbatim   */\n"
               "} u2_license_entry;\n\n")
    out.append(f"#define U2_LICENSE_COUNT {len(loaded)}u\n\n")
    out.append("static const u2_license_entry u2_license_table[U2_LICENSE_COUNT] = {\n")
    for title, path, text in loaded:
        origin = str(path.relative_to(REPO))
        out.append("    { %s, %s, %s },\n"
                   % (jsonish(title), jsonish(origin), c_string(text)))
    out.append("};\n\n")
    out.append(f"#endif /* {GUARD} */\n")
    return "".join(out)


def jsonish(s: str) -> str:
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true",
                    help="fail if the committed header does not match its sources")
    ap.add_argument("-o", "--output", default=str(OUT))
    args = ap.parse_args()

    want = build()
    out = pathlib.Path(args.output)

    if args.verify:
        have = out.read_text(encoding="utf-8") if out.exists() else ""
        if have != want:
            print("licenses_data.h is out of date with its sources "
                  "(fix: python3 engine/tools/gen_licenses.py)")
            # Say which entry drifted, not just that something did: "the header is
            # stale" sends a person to diff 14 KB by hand.
            if have:
                for i, (a, b) in enumerate(zip(have.splitlines(), want.splitlines())):
                    if a != b:
                        print(f"  first difference near generated line {i + 1}")
                        break
            return 1
        print(f"licenses_data.h matches its {len(ENTRIES)} sources")
        return 0

    out.write_text(want, encoding="utf-8")
    n = len(want.splitlines())
    print(f"wrote {out.relative_to(REPO)} ({n} lines, {len(ENTRIES)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
