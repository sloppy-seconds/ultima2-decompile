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
    """One file to emit: `src` copied to `dst`, both relative to the repo. A
    generated item carries `data` instead of a source file, and the verifier
    re-derives it rather than comparing against a file on disk."""

    def __init__(self, kind, src, dst, theme=None, note="", key=None, data=None):
        self.kind = kind          # atlas | color | picture | theme-file | generated
        self.src = Path(src)
        self.dst = Path(dst)
        self.theme = theme
        self.note = note
        self.data = data
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


def rel(p, base=None):
    """Display path: relative to `base` (default the working directory) when it
    fits there, else absolute. Nothing in this tool may derive paths from its own
    location: the same file gets copied next to a player's game and run from
    there, and assuming a checkout layout is what made themes land in
    `themes/<dirname>/EGATHEME.X/` instead of `themes/EGATHEME.X/` when the script
    was run beside the game itself."""
    p = Path(p).resolve()
    b = Path(base) if base else Path.cwd()
    try:
        return p.relative_to(b)
    except ValueError:
        return p


ATLAS_NAME = "EGATILES"


def default_theme_ini():
    """The manifest for a reshaped default theme. It describes the EGATILES it
    sits beside rather than inventing anything: 16x16 at 4bpp, identity mapping
    (no MAP.TSV is written), no palette of its own, and every scope claimed —
    which is what the v1 loader assumed for a bare EGATILES too, so reshaping the
    default cannot quietly narrow what the engine will draw with it."""
    return (
        "[theme]\n"
        "name = default\n"
        "tile_w = 16\n"
        "tile_h = 16\n"
        "bpp = 4\n"
        "pixel = nibble-high-left\n"
        "identity = yes\n"
        "scope = overworld,towns,dungeon,tower\n"
        "source = the fan pack's top-level EGATILES, reshaped by tools/build_themes.py\n"
    ).encode()


def theme_name_for(d, root):
    """Name a discovered theme from where it was found.

    A leading `EGATHEME.` is the vendor's spelling of "this is a theme" and
    carries no information the directory name does not already carry, so it is
    stripped. Otherwise the directory's own name is the theme name, and the source
    root itself is the default theme. Lower-cased, because the engine reports v1
    theme names lower-cased and matches them case-insensitively."""
    if d == root and not d.name.upper().startswith(THEME_PREFIX):
        return DEFAULT_THEME
    name = d.name.upper()
    if name.startswith(THEME_PREFIX):
        name = name[len(THEME_PREFIX):]
    return (name or d.name).lower()


def walk_dirs(root, max_depth):
    """Every directory under `root` to `max_depth`, hidden ones pruned."""
    root = Path(root).resolve()
    for dirpath, dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        dirnames[:] = [x for x in dirnames if not x.startswith(".")]
        if len(d.relative_to(root).parts) >= max_depth:
            dirnames[:] = []
        yield d, filenames


def scan_source(root, max_depth=3):
    """Inventory one source. Returns (items, report_rows, problems, theme_files).

    **A theme is a directory whose contents include a tile atlas.** Not one called
    `EGATHEME.*`: keying discovery on the vendor's directory name meant a pack that
    ships its themes under any other name produced a tree with no themes in it, and
    the engine then refused every theme by name while the builder reported success.
    Depth is the vendor's business too, so the walk goes a few levels down.

    What the theme is CALLED in the output is this tool's decision, and it is the
    layout the engine reads: `EGATHEME.<NAME>` for a named theme, the top level for
    the default one. `theme_files` maps each theme name to the set of filenames its
    source directory ships, which is what the half-copied-theme gate compares
    against — so that gate no longer has to assume a naming convention either.
    """
    root = Path(root).resolve()
    items, rows, problems, theme_files = [], [], [], {}
    if not root.is_dir():
        return (items, [("<missing>", "error", str(root))],
                [f"source is not a directory: {root}"], theme_files)

    themes_found = 0
    for d, filenames in walk_dirs(root, max_depth):
        names_upper = {f.upper() for f in filenames}
        is_theme = ATLAS_NAME in names_upper
        theme = theme_name_for(d, root) if is_theme else None
        if is_theme:
            themes_found += 1
        out_dir = (None if theme is None else
                   Path(DEFAULT_THEME) if theme == DEFAULT_THEME
                   else Path(THEME_PREFIX + theme.upper()))
        have = set()

        for f in sorted((e for e in d.iterdir() if e.is_file()),
                        key=lambda e: e.name.upper()):
            size = f.stat().st_size
            role, detail = classify_file(f.name, size)
            label = f"{rel(d)}/{f.name}"
            if role.startswith("bad"):
                problems.append(f"{f}: {detail}")
                rows.append((label, role, detail))
                continue
            if role not in ("atlas", "color", "picture"):
                rows.append((label, "ignore", detail))
                continue

            if role == "atlas" and size != TILE_ATLAS_BYTES:
                problems.append(f"{f} is {size} B, expected {TILE_ATLAS_BYTES} B")

            if theme is None:
                # Not a theme directory, so the only thing we want out of it is a
                # full-screen picture: `updated/` ships the whole PIC*-E set and
                # no atlas at all, and that is a complete answer, not a defect.
                if role == "picture":
                    items.append(Item("picture", f, Path(f.name), note=detail,
                                      key="PIC:" + PIC_RE.match(f.name.upper()).group("base")))
                    rows.append((label, "picture", detail))
                else:
                    rows.append((label, "ignore", detail))
                continue

            # Pictures. A theme's own pictures are copied INTO its directory, as
            # the pack ships them — dropping them because nothing reads them yet is
            # the half-copied-theme bug wearing a different hat, and the per-theme
            # completeness gate below is what notices. They are ALSO hoisted to the
            # root when they came from the default theme, because pic_ega.c
            # resolves pictures at the top level of the themes dir and nowhere else
            # (docs/ega-graphics.md § 3.1), so the default theme's art is the only
            # set the engine can actually draw today.
            if role == "picture":
                items.append(Item("theme-file", f, out_dir / f.name,
                                  theme=theme, note=detail))
                have.add(f.name.upper())
                if theme == DEFAULT_THEME:
                    items.append(Item("picture", f, Path(f.name), note=detail,
                                      key="PIC:" + PIC_RE.match(f.name.upper()).group("base")))
                    rows.append((label, f"picture ({theme}, also at root)", detail))
                else:
                    rows.append((label, f"picture -> {theme}", detail))
                continue

            have.add("TILES" if (theme == DEFAULT_THEME and role == "atlas")
                     else f.name.upper())
            if theme == DEFAULT_THEME:
                # The default theme is reshaped into a v2 directory like every
                # other theme. A bare EGATILES at the root is the VENDOR's layout,
                # and the engine accepts `default/THEME.INI` through the same call,
                # so there is no reason for our tree to keep the loose file.
                dst = Path(DEFAULT_THEME) / ("TILES" if role == "atlas" else f.name)
                items.append(Item("theme-file", f, dst, theme=DEFAULT_THEME, note=detail))
            else:
                items.append(Item("theme-file", f, out_dir / f.name, theme=theme))
            rows.append((label, f"{role} -> {theme}", detail))

        if is_theme and theme == DEFAULT_THEME:
            # The manifest for the reshaped default. It describes the atlas it
            # sits beside: 16x16 at 4bpp, identity mapping, no palette of its own,
            # and every scope claimed, which is what the v1 loader assumed too.
            have.add("THEME.INI")
            items.append(Item("generated", FMTOWNS_XWALK,
                              Path(DEFAULT_THEME) / "THEME.INI",
                              theme=DEFAULT_THEME, data=default_theme_ini(),
                              key="GEN:DEFAULT/THEME.INI"))

        if is_theme and have:
            theme_files.setdefault(theme, set()).update(have)

    if themes_found == 0:
        rows.append((str(rel(root)), "no-themes",
                     "no directory with an " + ATLAS_NAME + " here; pictures only"))
    return items, rows, problems, theme_files


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


# ---------------------------------------------------------------------------
# Slice B: the FM Towns theme, format v2.
#
# Everything here is DERIVED: the tile pool comes off the player's own FM Towns
# disc through the same reader tools/fmtowns_xwalk.py uses (no second ISO parser,
# no second decoder, both of which would be free to drift), and the art_index ->
# tile mapping is read from disasm/fmtowns-crosswalk.tsv, which is itself
# generated and gated. Nothing in this section re-derives a mapping, and nothing
# in it hand-copies a crosswalk row.
#
# The pool holds EVERY frame the crosswalk names, not just the first. Slice B
# draws list[0] and nothing else, but collapsing the set on the way into the file
# would mean slice C rebuilds the mapping layer to add animation — see the handoff
# § 5. The dropped-frame decision is therefore recorded as an engine policy
# (`frames = first` in THEME.INI) rather than as data loss.
# ---------------------------------------------------------------------------

FMTOWNS_XWALK = "disasm/fmtowns-crosswalk.tsv"
FMTOWNS_NAME = "fmtowns"
FMTOWNS_SCOPE = "overworld,towns"      # the crosswalk's own scope caveat, verbatim


def load_crosswalk(path):
    """[(art_index, [BANK/tile, ...]), ...] in file order. Rows are tab-separated
    and the header is comments, same contract `--check` gates."""
    rows = []
    with open(path, encoding="utf-8") as fh:
        for ln in fh:
            ln = ln.rstrip("\n")
            if not ln or ln.startswith("#"):
                continue
            cols = ln.split("\t")
            if len(cols) < 2:
                continue
            toks = [t.strip() for t in cols[1].split(",") if t.strip()]
            rows.append((int(cols[0], 16), toks))
    return rows


def fmtowns_theme(xwalk_path=None):
    """Derive the v2 theme as {relpath: bytes}. Returns (files, (stats, problems)).

    A missing disc or crosswalk is a hard stop, not an empty theme: a themes tree
    that quietly omits the FM Towns art renders as a theme bug and not a build
    bug, which is the exact failure this whole tool is built against.
    """
    problems = []
    xwalk = Path(xwalk_path) if xwalk_path else REPO / FMTOWNS_XWALK
    if not xwalk.is_file():
        raise SystemExit(f"no crosswalk at {xwalk} — regenerate it with "
                         f"`python3 tools/fmtowns_xwalk.py --export` before "
                         f"building a fmtowns theme")
    sys.path.insert(0, str(REPO / "tools"))
    try:
        import fmtowns_xwalk as fx
    except ImportError as e:
        raise SystemExit(f"cannot import tools/fmtowns_xwalk.py to read the FM "
                         f"banks ({e}) — the v2 theme needs its ISO reader")
    if not os.path.isdir(fx.DISC):
        raise SystemExit(f"no FM Towns media in {fx.DISC}")
    files = fx.disc_files(fx.find_disc())

    banks = {}
    def tile_pixels(token):
        bank, _, n = token.partition("/")
        bank = bank.upper()
        if bank not in banks:
            key = bank + ".TIF"
            if key not in files:
                raise SystemExit(f"no GRAPH/{key} on the FM Towns disc")
            banks[bank] = fx.decode_bank(files[key])
        tiles = banks[bank]
        i = int(n)
        if i < 0 or i >= len(tiles):
            raise SystemExit(f"{token}: bank {bank} has {len(tiles)} tiles")
        return tiles[i]

    def pack(px):
        """index list -> 4bpp packed rows, high nibble = left pixel. The banks
        measure zero nibbles above 7, so the upper half of the field is simply
        never set; nothing here remaps or clamps."""
        out = bytearray(len(px) // 2)
        for i in range(0, len(px), 2):
            out[i // 2] = ((px[i] & 0xF) << 4) | (px[i + 1] & 0xF)
        return bytes(out)

    pool, order = {}, []
    rows = load_crosswalk(xwalk)
    map_lines = []
    multi = 0
    for art, toks in rows:
        idxs = []
        for t in toks:
            if t not in pool:
                pool[t] = len(order)
                order.append(t)
            idxs.append(pool[t])
        if len(idxs) > 1:
            multi += 1
        map_lines.append((art, idxs, toks))
    if len(rows) != 64:
        problems.append(f"crosswalk has {len(rows)} rows, expected 64")
    missing = sorted(set(range(64)) - {a for a, _, _ in map_lines})
    if missing:
        problems.append(f"crosswalk has no row for art "
                        f"{', '.join(f'{m:02X}' for m in missing)}")

    tiles = b"".join(pack(tile_pixels(t)) for t in order)

    # PALETTE.RGB: 16 x 3. Only 0..7 are measured (§ 3 of fmtowns-graphics.md);
    # 8..15 are zero-filled because the art never indexes above 7, and that is
    # stated here rather than left for someone to discover as a colour bug.
    pal = bytearray(48)
    for i, (r, g, b) in enumerate(fx.PAL[:8]):
        pal[i * 3:i * 3 + 3] = bytes((r, g, b))

    ini = (
        "[theme]\n"
        f"name = {FMTOWNS_NAME}\n"
        f"tile_w = {fx.TILE_W}\n"
        f"tile_h = {fx.TILE_H}\n"
        "bpp = 4\n"
        "pixel = nibble-high-left\n"
        "palette = PALETTE.RGB\n"
        "map = MAP.TSV\n"
        "identity = no\n"
        f"scope = {FMTOWNS_SCOPE}\n"
        "source = FM Towns (1990) GRAPH banks\n"
        "frames = first\n"
        f"tiles_pool = {len(order)}\n"
        f"art_count = {len(map_lines)}\n"
        f"art_with_multiple_frames = {multi}\n"
        f"crosswalk = {FMTOWNS_XWALK}\n"
        "# `frames = first` is a slice-B policy, not a claim about the original:\n"
        "# MAP.TSV keeps every frame the crosswalk names, and the engine draws\n"
        "# list[0] until animation exists. The frames are in TILES, so nothing\n"
        "# was thrown away to get here.\n"
    )

    mtsv = (
        "# MAP.TSV -- DOS art index -> tile indices into TILES, generated by\n"
        "# tools/build_themes.py from " + FMTOWNS_XWALK + ". Do not hand-edit.\n"
        "# Column 3 repeats the source BANK/tile tokens for provenance. A row is\n"
        "# set-valued: the engine uses the first index and keeps the rest.\n"
        "# art\ttiles\tsource\n"
    )
    for art, idxs, toks in map_lines:
        mtsv += f"{art:02X}\t{','.join(str(i) for i in idxs)}\t{','.join(toks)}\n"

    return ({"THEME.INI": ini.encode(), "TILES": tiles, "PALETTE.RGB": bytes(pal),
             "MAP.TSV": mtsv.encode()},
            ({"pool": len(order), "art": len(map_lines), "multi": multi}, problems))


def build_plan(sources, with_fmtowns=False):
    """Inventory every source and resolve conflicts. The FIRST source that
    provides a destination wins; later ones are reported as shadowed rather than
    merged, because two atlases cannot both be the default theme and silently
    picking the last one is how a build becomes unreproducible."""
    plan, rows, problems, shadowed = [], [], [], []
    theme_files, seen = {}, {}
    for src in sources:
        items, inv, probs, tfiles = scan_source(src)
        rows.append((src, inv))
        problems += [f"{src}: {p}" for p in probs]
        for name, files in tfiles.items():
            theme_files.setdefault(name, set()).update(files)
        for it in items:
            key = it.key or str(it.dst).upper()
            if key in seen:
                shadowed.append((it, seen[key]))
                continue
            seen[key] = it
            plan.append(it)
    if with_fmtowns:
        gen, note = fmtowns_theme()
        for path in sorted(gen):
            it = Item("generated", FMTOWNS_XWALK, Path(FMTOWNS_NAME) / path,
                      theme=FMTOWNS_NAME, data=gen[path],
                      key="GEN:" + path.upper())
            seen[str(it.dst).upper()] = it
            plan.append(it)
        rows.append((f"generated: {FMTOWNS_NAME}", [(k, "generated", f"{len(v)} B")
                                                   for k, v in sorted(gen.items())]))
        problems += [f"fmtowns: {p}" for p in note[1]]
        theme_files.setdefault(FMTOWNS_NAME, set()).update(
            {Path(k).name.upper() for k in gen})
    return plan, rows, problems, shadowed, theme_files


def theme_names(plan):
    names = set()
    for it in plan:
        if it.kind == "atlas":
            names.add(DEFAULT_THEME)
        elif it.theme:
            names.add(it.theme)
    return names


def manifest_rows(plan, out):
    rows = []
    for it in sorted(plan, key=lambda i: str(i.dst).upper()):
        if it.data is not None:
            body = it.data
            origin = f"generated:{it.theme}"
        else:
            s = it.src_abs()
            if not s.is_file():
                rows.append(None)
                continue
            body = s.read_bytes()
            origin = str(rel(it.src))
        rows.append(f"{it.dst.as_posix()}\t{it.kind}\t{origin}\t"
                    f"{len(body)}\t{hashlib.sha256(body).hexdigest()[:16]}")
    return [r for r in rows if r]


def do_build(plan, out, sources):
    out.mkdir(parents=True, exist_ok=True)
    for it in plan:
        d = it.dst_abs(out)
        d.parent.mkdir(parents=True, exist_ok=True)
        if it.data is not None:
            d.write_bytes(it.data)
        else:
            shutil.copyfile(it.src_abs(), d)
    rows = manifest_rows(plan, out)
    with (out / MANIFEST).open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("# built by tools/build_themes.py — do not hand-edit, regenerate\n")
        for s in sources:
            fh.write(f"# source {s}\n")
        if any(it.data is not None for it in plan):
            fh.write(f"# source {FMTOWNS_XWALK} + the FM Towns GRAPH banks\n")
        fh.write("# dst\tkind\tsource\tsize\tsha256:16\n")
        fh.write("\n".join(rows) + "\n")
    return len(plan)


def do_verify(plan, out, sources, theme_files):
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
        d = it.dst_abs(out)
        if it.data is not None:
            if not d.is_file():
                fails.append(f"missing: {d} (generated)")
                continue
            if d.read_bytes() != it.data:
                fails.append(f"generated file does not match a fresh derivation: {d}")
            continue
        s = it.src_abs()
        if not d.is_file():
            fails.append(f"missing: {d} (from {it.src})")
            continue
        if s.is_file() and s.stat().st_size != d.stat().st_size:
            fails.append(f"size differs: {d} is {d.stat().st_size} B, source {it.src} is {s.stat().st_size} B")
            continue
        if s.is_file() and not filecmp.cmp(str(s), str(d), shallow=False):
            fails.append(f"not byte-identical to source: {d}")

    # Per-theme completeness, stated as its own verdict so the message names the
    # file. The loop above already catches it; this is the line a human reads, and
    # it is the gate that catches the half-recoloured theme. The expected file set
    # comes from the discovery pass, so it does not care what the source directory
    # was called or how deep it sat.
    src_theme_files = theme_files
    # Where each theme actually landed. Taken from the plan rather than from a
    # naming convention, because the layout is this tool's decision and it differs
    # by format: a v1 theme is EGATHEME.<NAME>/ and a v2 theme is <name>/.
    theme_outdir = {}
    for it in plan:
        if it.theme and it.theme != DEFAULT_THEME and it.theme not in theme_outdir:
            theme_outdir[it.theme] = it.dst.parent

    for theme, files in sorted(src_theme_files.items()):
        if theme == DEFAULT_THEME:
            continue     # the default theme IS the top level; the plan loop above
                         # already compared every one of its files byte for byte
        sub = theme_outdir.get(theme)
        if sub is None:
            fails.append(f"theme '{theme}' was discovered but planned nowhere")
            continue
        d = out / sub
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
            print(f"   {it.dst}  from {rel(it.src)}   (kept {rel(kept.src)}){same}")
    if problems:
        print("-- problems")
        for p in problems:
            print(f"   {p}")
    print(f"-- plan: {len(plan)} file(s) -> {out}")
    for it in sorted(plan, key=lambda i: str(i.dst).upper()):
        print(f"   {it.kind:<11} {str(it.dst):<28} <- {rel(it.src)}")
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
    ap.add_argument("--fmtowns", action="store_true",
                    help=f"also emit the derived v2 '{FMTOWNS_NAME}' theme (needs the FM "
                         f"Towns disc and {FMTOWNS_XWALK}). Implied by --verify when the "
                         f"out dir already holds that theme.")
    args = ap.parse_args()

    # Default sources are the two places the fan pack sits on a developer
    # checkout. They are candidates, not assumptions: if the script is running
    # beside a player's game instead, there are no defaults and --source is
    # required, which is said out loud rather than building an empty tree.
    sources = [Path(s).resolve() for s in
               (args.source or [s for s in (str(REPO / "references/u2upgrade"),
                                            str(REPO / "original/updated"))
                                if Path(s).is_dir()])]
    if not sources:
        sys.exit("no source directories found and no defaults exist next to this "
                 "script — pass --source DIR")

    # Relative --out and --source resolve against the working directory, NOT
    # against wherever this script happens to live. Deriving them from __file__ is
    # what wrote themes into themes/<dirname>/EGATHEME.X/ when the script was run
    # beside the game, and the engine then refused every theme by name.
    out = Path(args.out).resolve()

    # Refuse the two places that hold the player's pristine media, and refuse to
    # build a tree inside a source (which would make the next scan see its own
    # output as input).
    low = str(out).lower()
    if "/original/" in low or "/references/" in low:
        sys.exit(f"refusing to write into original/ or references/ (got {out})")
    for s in sources:
        try:
            out.resolve().relative_to(Path(s).resolve())
            sys.exit(f"refusing to write inside a source directory: {out} is under {s}")
        except (ValueError, OSError):
            pass

    # A tree that already contains the derived theme must be verified with it, or
    # every one of its files would read as a stray. So the flag is implied by the
    # tree, not remembered by the operator.
    want_fmtowns = args.fmtowns or (out / FMTOWNS_NAME).is_dir()
    plan, rows, problems, shadowed, theme_files = build_plan(sources, want_fmtowns)
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
        fails = do_verify(plan, out, sources, theme_files)
        for f in fails:
            print(f"  FAIL  {f}")
        print(f"{'FAIL' if fails else 'PASS'}: {len(plan)} file(s) verified in {out}")
        return 1 if fails else 0

    n = do_build(plan, out, sources)
    print(f"built {n} file(s) into {out}")
    fails = do_verify(plan, out, sources, theme_files)
    for f in fails:
        print(f"  FAIL  {f}")
    if fails:
        print(f"FAIL: the tree just written does not match the sources in {out}")
        return 1
    print(f"PASS: {out} matches its sources; themes: {', '.join(sorted(theme_names(plan)))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
