#!/usr/bin/env python3
"""
build_themes.py — assemble one themes/ tree out of the player's own EGA art.

Slice A of docs/handoff-themes-builder.md: no engine change, no re-encoding, no
FM Towns. The output is a directory the existing `--ega-theme-dir` already
understands, so Ctrl-T cycles across art that came from more than one place.

WHAT EACH SOURCE ACTUALLY CONTRIBUTES (measured, not assumed — see the handoff
§ 0 and § 2.2). The tile atlas `EGATILES` and the `EGATHEME.*` directories exist
ONLY in the upgrade package; `original/updated/` has no atlas at all, but it is
the only source with the full `PIC*-E` picture set. Taking one source and
assuming it is complete is how you get a half-recoloured game.

THE RULES THIS TOOL IS BUILT AROUND:

  * Copy WHOLE theme directories, never selected files. A theme is EGATILES plus
    an optional EGACOLOR plus optional PIC*.EGA, and the optionality is per-theme
    (EGATHEME.ALT ships EGATILES alone; .10 and .C64 ship all three). Selective
    copying silently drops a theme's own extras.
  * Emit EGATILES byte-identical. Nothing here decodes or re-encodes the atlas.
  * No fall-through: an explicit --out is the only place it writes, and it
    refuses to write into original/ or references/ (the same posture as
    tools/u2_mkprobe.py), because those hold the player's pristine media.
  * A build is not done until it has been verified. `--build` ends by running the
    same checks as `--verify`, so a copy that silently landed short is red.

MANIFEST: the tree carries `_BUILD.tsv`, one row per emitted file naming the
source it came from. It is what makes "which EGATILES is this?" answerable after
the fact, and it is what the verifier diffs against the plan. Comment lines
(starting with `#`) are ignored by the verifier, which is where the build
timestamp goes so the data rows stay reproducible.

Usage:
    python3 tools/build_themes.py --report
    python3 tools/build_themes.py --dry-run
    python3 tools/build_themes.py                      # build + verify
    python3 tools/build_themes.py --verify             # check an existing tree
    python3 tools/build_themes.py --source DIR [--source DIR ...] --out themes/
"""

import argparse
import filecmp
import hashlib
import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Measured shapes. EGATILES is 65 x 128 = 8320 with no header (tiles_ega.h); the
# engine accepts anything >= 64 tiles and ignores the 65th, so a short file is
# reported rather than padded. A PIC*-E picture is one byte per pixel at
# 320x200 = 64000 (pic_ega.c).
TILE_ATLAS_BYTES = 8320
TILE_ATLAS_MIN = 8192          # 64 * 128, what the engine actually reads
PIC_EGA_BYTES = 64000

THEME_PREFIX = "EGATHEME."
DEFAULT_THEME = "default"
MANIFEST = "_BUILD.tsv"
COLOR_TABLE_BYTES = 32         # measured: all three shipped EGACOLOR files, and
                               # the driver reads exactly 0x20 bytes (see § 2.4
                               # of the handoff and docs/ega-graphics.md)

# PICDNG.EGA / PICDNG-E / picdng.ega — the seven shipped bases are three letters
# (DNG DRA SPA MIN OUT TWN CAS), the engine tries both separators and both cases
# (pic_ega.c make_name), so any spelling is loadable and we keep the source's.
PIC_RE = re.compile(r"^PIC(?P<base>[A-Z]{3,4})[-.](EGA|E)$")


class Item:
    """One file to emit: `src` copied to `dst`, both relative to the repo."""

    def __init__(self, kind, src, dst, theme=None, note="", key=None):
        self.kind = kind          # atlas | color | picture | theme-file
        self.src = Path(src)
        self.dst = Path(dst)
        self.theme = theme
        self.note = note
        # Dedup key. Pictures key on their BASE, not their filename: PICDNG.EGA
        # and PICDNG-E are the same slot to the engine (pic_ega.c tries `-E`
        # before `.EGA` inside a directory), so shipping both would let the
        # suffix order decide which art draws, silently and opposite to the
        # source order. One file per base, first source wins, shadow reported.
        self.key = key

    def src_abs(self):
        return self.src if self.src.is_absolute() else REPO / self.src

    def dst_abs(self, out):
        return self.dst if self.dst.is_absolute() else out / self.dst


def rel(p, base):
    """Path relative to the repo when it fits there, else absolute. Keeps the
    report readable and the manifest portable across checkouts."""
    p = Path(p).resolve()
    try:
        return p.relative_to(base)
    except ValueError:
        return p


def classify_file(name, size):
    """(role, detail) for one file in a source. Unknown roles are IGNORED, never
    guessed at: the fan pack ships patchers, .pat deltas, .IDX indexes and CGA
    art in the same directories as the EGA themes, and a builder that invents
    roles for those will put game data in a themes tree. The ignore reasons are
    spelled out because this table is the inventory a human reads before copying
    anything — 'not theme content' would tell them nothing."""
    up = name.upper()
    if up == "EGATILES":
        if size < TILE_ATLAS_MIN:
            return ("bad-atlas", f"EGATILES is {size} B, below the {TILE_ATLAS_MIN} B the engine reads")
        return ("atlas", f"{size} B, 4bpp 16x16 x65")
    if up == "EGACOLOR":
        if size != COLOR_TABLE_BYTES:
            return ("bad-color", f"EGACOLOR is {size} B, not the {COLOR_TABLE_BYTES} B the driver reads")
        return ("color", f"{size} B colour-index remap (ega.drv loads exactly 0x20)")
    m = PIC_RE.match(up)
    if m:
        if size < PIC_EGA_BYTES:
            return ("bad-picture", f"{name} is {size} B, not the {PIC_EGA_BYTES} B a PIC*-E carries")
        return ("picture", f"base PIC{m.group('base')}, {size} B")
    if up == "CGATILES":
        return ("ignore", "CGA atlas; the engine's CGA tiles come from the exe, not the pack")
    if up.endswith(".IDX"):
        return ("ignore", "fan-pack index for the compressed CGA pictures; pic_ega.c reads raw art")
    if up.endswith((".PAT", ".EXE", ".COM", ".DRV", ".PAL", ".CFG", ".INI", ".TXT")):
        return ("ignore", "patcher, driver or config, not art")
    if re.match(r"^PIC[A-Z]{3,4}$", up):
        return ("ignore", "CGA picture (16 KB planar); the EGA spelling is the PIC*-E sibling")
    if re.match(r"^(MAP|MON|TLK)[GX]", up):
        return ("ignore", "game world data, belongs in --data-dir, not a themes dir")
    return ("ignore", "unrecognised; not copied")


def scan_source(root):
    """Inventory one source. Returns (items, report_rows, problems) where
    report_rows is [(name, role, detail)] for every top-level entry, in sorted
    order, so the inventory can be read before anything is copied."""
    root = Path(root)
    items, rows, problems = [], [], []
    if not root.is_dir():
        return items, [("<missing>", "error", str(root))], [f"source is not a directory: {root}"]

    for entry in sorted(root.iterdir(), key=lambda e: e.name.upper()):
        up = entry.name.upper()
        if entry.is_dir():
            if not up.startswith(THEME_PREFIX):
                rows.append((entry.name, "ignore", "directory, not " + THEME_PREFIX + "*"))
                continue
            theme = up[len(THEME_PREFIX):].lower()
            inner = sorted((e for e in entry.iterdir() if e.is_file()),
                           key=lambda e: e.name.upper())
            names = {e.name.upper() for e in inner}
            if "EGATILES" not in names:
                # A EGATHEME.* with no atlas is not a theme: the engine would
                # list the name and then fail to load it. Refuse it loudly.
                problems.append(f"{entry}/EGATILES is absent — {entry.name} is not a loadable theme")
                rows.append((entry.name, "bad-theme", "no EGATILES inside"))
                continue
            for f in inner:
                size = f.stat().st_size
                role, detail = classify_file(f.name, size)
                if role == "atlas" and size != TILE_ATLAS_BYTES:
                    problems.append(f"{f} is {size} B, expected {TILE_ATLAS_BYTES} B")
                if role.startswith("bad"):
                    problems.append(f"{entry.name}/{f.name}: {detail}")
                    rows.append((f"{entry.name}/{f.name}", role, detail))
                    continue
                if role in ("atlas", "color", "picture"):
                    items.append(Item("theme-file", rel(f, REPO),
                                      rel(entry.name, REPO) / f.name, theme=theme))
                    rows.append((f"{entry.name}/{f.name}", "theme-" + role, detail))
                else:
                    rows.append((f"{entry.name}/{f.name}", "ignore", detail))
            continue

        size = entry.stat().st_size
        role, detail = classify_file(entry.name, size)
        if role in ("atlas", "color", "picture"):
            key = None
            if role == "picture":
                key = "PIC:" + PIC_RE.match(entry.name.upper()).group("base")
            items.append(Item(role, rel(entry, REPO), Path(entry.name),
                              theme=DEFAULT_THEME if role == "atlas" else None,
                              note=detail, key=key))
        elif role.startswith("bad"):
            problems.append(f"{entry}: {detail}")
        rows.append((entry.name, role, detail))
    return items, rows, problems


def build_plan(sources):
    """Inventory every source and resolve conflicts. The FIRST source that
    provides a destination wins; later ones are reported as shadowed rather than
    merged, because two atlases cannot both be the default theme and silently
    picking the last one is how a build becomes unreproducible."""
    plan, rows, problems, shadowed = [], [], [], []
    seen = {}
    for src in sources:
        items, inv, probs = scan_source(src)
        rows.append((src, inv))
        problems += [f"{src}: {p}" for p in probs]
        for it in items:
            key = it.key or str(it.dst).upper()
            if key in seen:
                shadowed.append((it, seen[key]))
                continue
            seen[key] = it
            plan.append(it)
    return plan, rows, problems, shadowed


def theme_names(plan):
    names = set()
    for it in plan:
        if it.kind == "atlas":
            names.add(DEFAULT_THEME)
        elif it.kind == "theme-file" and it.theme:
            names.add(it.theme)
    return names


def manifest_rows(plan, out):
    rows = []
    for it in sorted(plan, key=lambda i: str(i.dst).upper()):
        s = it.src_abs()
        if not s.is_file():
            rows.append(None)
            continue
        h = hashlib.sha256()
        with s.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        rows.append(f"{it.dst.as_posix()}\t{it.kind}\t{it.src.as_posix()}\t"
                    f"{s.stat().st_size}\t{h.hexdigest()[:16]}")
    return [r for r in rows if r]


def do_build(plan, out, sources):
    out.mkdir(parents=True, exist_ok=True)
    for it in plan:
        d = it.dst_abs(out).parent
        d.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(it.src_abs(), it.dst_abs(out))
    rows = manifest_rows(plan, out)
    with (out / MANIFEST).open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("# built by tools/build_themes.py — do not hand-edit, regenerate\n")
        for s in sources:
            fh.write(f"# source {s}\n")
        fh.write("# dst\tkind\tsource\tsize\tsha256:16\n")
        fh.write("\n".join(rows) + "\n")
    return len(plan)


def do_verify(plan, out, sources):
    """Re-derive the plan from the sources and prove the tree on disk matches it.
    Every check below has a failure mode this project has already been bitten by:
    a missing EGACOLOR (half-recoloured theme), a short EGATILES (silent CGA
    fallback), a stale PICDNG.EGA (splash from the wrong pack), a stray file
    nobody built (hand-edited tree)."""
    fails = []
    if not out.is_dir():
        return [f"out dir does not exist: {out}"]

    want = {str(it.dst).upper(): it for it in plan}

    for it in plan:
        s, d = it.src_abs(), it.dst_abs(out)
        if not d.is_file():
            fails.append(f"missing: {d} (from {it.src})")
            continue
        if s.is_file() and s.stat().st_size != d.stat().st_size:
            fails.append(f"size differs: {d} is {d.stat().st_size} B, source {it.src} is {s.stat().st_size} B")
            continue
        if s.is_file() and not filecmp.cmp(str(s), str(d), shallow=False):
            fails.append(f"not byte-identical to source: {d}")

    # Per-theme completeness, stated as its own verdict so the message names the
    # file. The loop above already catches it; this is the line a human reads.
    src_theme_files = {}
    for src in sources:
        root = Path(src)
        if not root.is_dir():
            continue
        for entry in root.iterdir():
            up = entry.name.upper()
            if entry.is_dir() and up.startswith(THEME_PREFIX):
                theme = up[len(THEME_PREFIX):].lower()
                have = {f.name.upper() for f in entry.iterdir()
                        if f.is_file() and classify_file(f.name, f.stat().st_size)[0]
                        in ("atlas", "color", "picture")}
                src_theme_files.setdefault(theme, set()).update(have)
    for theme, files in sorted(src_theme_files.items()):
        d = out / f"{THEME_PREFIX}{theme.upper()}"
        if not d.is_dir():
            fails.append(f"theme '{theme}' has no directory in {out}")
            continue
        have = {f.name.upper() for f in d.iterdir() if f.is_file()}
        for missing in sorted(files - have):
            fails.append(f"theme '{theme}' is missing {missing} that its source ships "
                         f"(half-copied theme)")
        for extra in sorted(have - files):
            fails.append(f"theme '{theme}' has {extra}, which its source does not ship")

    # Strays: anything in the tree the plan did not build.
    for dirpath, dirnames, filenames in os.walk(out):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            p = Path(dirpath) / fn
            r = rel(p, out)
            if r.name == MANIFEST:
                continue
            if str(r).upper() not in want:
                fails.append(f"stray file not built by this tool: {r}")

    mf = out / MANIFEST
    if not mf.is_file():
        fails.append(f"no {MANIFEST} in {out} — was it built by this tool?")
    else:
        data = [ln for ln in mf.read_text(encoding="utf-8").splitlines()
                if ln and not ln.startswith("#")]
        want_rows = set(manifest_rows(plan, out))
        for ln in data:
            if ln not in want_rows:
                fails.append(f"{MANIFEST} row does not match the sources: {ln}")
        for ln in sorted(want_rows - set(data)):
            fails.append(f"{MANIFEST} is missing a row: {ln}")

    return fails


def print_report(rows, problems, shadowed, plan, out):
    for src, inv in rows:
        print(f"-- source {src}")
        for name, role, detail in inv:
            print(f"   {role:<12} {name:<24} {detail}")
    if shadowed:
        print("-- shadowed by an earlier --source (first source wins)")
        for it, kept in shadowed:
            same = ""
            if it.kind == "picture" and it.src_abs().is_file() and kept.src_abs().is_file():
                same = ("  [identical bytes]"
                        if filecmp.cmp(str(it.src_abs()), str(kept.src_abs()), shallow=False)
                        else "  [BYTES DIFFER — the kept file is what will draw]")
            print(f"   {it.dst}  from {it.src}   (kept {kept.src}){same}")
    if problems:
        print("-- problems")
        for p in problems:
            print(f"   {p}")
    print(f"-- plan: {len(plan)} file(s) -> {out}")
    for it in sorted(plan, key=lambda i: str(i.dst).upper()):
        print(f"   {it.kind:<11} {str(it.dst):<28} <- {it.src}")
    names = sorted(theme_names(plan))
    print(f"-- themes the engine will list: {', '.join(names) if names else '(none)'}")
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", action="append", default=None,
                    help="source directory (repeatable; first source wins on conflict). "
                         "Default: references/u2upgrade and original/updated, when present.")
    ap.add_argument("--out", default="themes", help="output themes dir (default themes/)")
    ap.add_argument("--dry-run", action="store_true", help="print the plan, write nothing")
    ap.add_argument("--report", action="store_true", help="print the full inventory of every source")
    ap.add_argument("--verify", action="store_true",
                    help="check --out against the sources and exit non-zero on any drift")
    args = ap.parse_args()

    sources = args.source or [s for s in ("references/u2upgrade", "original/updated")
                              if (REPO / s).is_dir()]
    if not sources:
        sys.exit("no source directories found (pass --source)")

    out = Path(args.out)
    out = out if out.is_absolute() else REPO / out

    # Refuse the two places that hold the player's pristine media, and refuse to
    # build a tree inside a source (which would make the next scan see its own
    # output as input).
    low = str(out).lower()
    if "/original/" in low or "/references/" in low:
        sys.exit(f"refusing to write into original/ or references/ (got {out})")
    for s in sources:
        sp = Path(s) if Path(s).is_absolute() else REPO / s
        try:
            out.resolve().relative_to(sp.resolve())
            sys.exit(f"refusing to write inside a source directory: {out} is under {s}")
        except (ValueError, OSError):
            pass

    plan, rows, problems, shadowed = build_plan(sources)
    if args.report:
        print_report(rows, problems, shadowed, plan, out)
    if args.dry_run:
        if not args.report:
            print_report(rows, problems, shadowed, plan, out)
        print("-- dry run: nothing written")
        return 1 if problems else 0

    if problems:
        if not args.report:
            print_report(rows, problems, shadowed, plan, out)
        sys.exit("refusing to build: fix the problems above")

    if args.verify:
        fails = do_verify(plan, out, sources)
        for f in fails:
            print(f"  FAIL  {f}")
        print(f"{'FAIL' if fails else 'PASS'}: {len(plan)} file(s) verified in {out}")
        return 1 if fails else 0

    n = do_build(plan, out, sources)
    print(f"built {n} file(s) into {out}")
    fails = do_verify(plan, out, sources)
    for f in fails:
        print(f"  FAIL  {f}")
    if fails:
        print(f"FAIL: the tree just written does not match the sources in {out}")
        return 1
    print(f"PASS: {out} matches its sources; themes: {', '.join(sorted(theme_names(plan)))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
