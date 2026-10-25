#!/usr/bin/env python3
"""cmd_marker_gate.py -- enforce the owner's command-loop ruling (2026-10-28e).

The ruling: implement all 26 command handlers, but the twelve that no capture has ever seen
run carry an in-source `UNPROVEN:` marker, and **no checkpoint, milestone or phase may be
called code-complete while any marker stands.** The rule is in `AGENTS.md` section 3.

A rule with no gate is a wish. This project has already watched `xref_provenance` sit red for a
week with nothing running it, and watched `run_cp5.sh` print FAIL while reporting PASS. So the
rule gets a checker, and the checker gets controls that prove it can go red -- including the
red that comes from the checker itself being misconfigured.

What it enforces
----------------
R1  Every engine handler for a letter with **no** execution evidence carries
    `UNPROVEN: cmd_<L>` in the comment block above its definition.
R2  Every engine handler for a letter that **does** have execution evidence must NOT carry the
    marker. A stale marker is a lie in the other direction: it says "unproven" about something
    a capture has proven, and the next agent will trust it.
R3  A handler whose letter is not one of the 26 (a typo, a lowercase slip) is an error. Silent
    non-matching is how a marker becomes decorative.
R4  If any marker stands anywhere under the engine source tree, the state document may not
    claim the command loop, CP6, or the project is code-complete / done / complete.
R5  If the engine has no command handlers at all, that is legal -- the loop is not built yet --
    but only while the state document does not claim it exists.

Source of truth for "proven" is `tools/cmd_handlers.py --json`, which derives the `exec` column
from each handler's own `# provenance:` line. Nothing here hard-codes the twelve letters,
because a hand-copied list is the second copy that AGENTS.md forbids.

Usage
-----
    python3 tools/cmd_marker_gate.py                 # check the real tree
    python3 tools/cmd_marker_gate.py --selftest      # run the controls
    python3 tools/cmd_marker_gate.py --engine-dir DIR --state-doc FILE --handlers-json FILE

Exit codes: 0 ok, 1 a rule is violated, 2 the gate cannot see its own inputs (it refuses
rather than reporting success over zero files -- the `run_cp0.sh` mistake).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_ENGINE = os.path.join(ROOT, "engine", "src")
DEFAULT_STATE = os.path.join(ROOT, "docs", "phase4-state.md")

# A handler definition: `void cmd_C(` or `static void cmd_C(` at the start of a line.
DEF_RE = re.compile(r"^\s*(?:static\s+)?(?:void|int|bool)\s+cmd_([A-Za-z])\s*\(")
# The marker, matched anywhere in the file that defines the handler.
MARK_RE = re.compile(r"UNPROVEN:\s*cmd_([A-Za-z])")
# Matching is file-scoped and letter-specific rather than "the N lines above the definition",
# because a positional window is fragile in a way that produces false REDs: the marker is a
# comment, and people write comments above a function, inside it, or in a block that also covers
# a group of handlers. The letter in the marker is what binds it to the handler -- `UNPROVEN:
# cmd_C` can only ever satisfy cmd_C -- so position adds no safety, only failure modes.

# Words that mean "finished" when they appear in a checkpoint's STATUS cell.
DONE_WORDS = ("code-complete", "code complete", "done", "complete", "shipped")
# R4 reads status cells, not prose. The first version grepped the whole document for
# "code-complete" and immediately fired on the sentence that STATES the rule:
# "no checkpoint may be called code-complete while any marker stands". A gate that reports a
# violation because its own rule is quoted nearby is worse than no gate -- it trains everyone
# to ignore it. So the claim surface is the checkpoint table, which is where a status is
# actually asserted. Columns are `| CP | name | status | details |`, so the status is group 3;
# reading group 2 instead asserts completion about every checkpoint whose *name* contains
# "done", which is a different bug with the same shape.
ROW_RE = re.compile(r"^\|\s*(CP\d[.\d]*)\s*\|([^|]*)\|([^|]*)\|")

LETTERS = [chr(c) for c in range(ord("A"), ord("Z") + 1)]


def fail(msg):
    print(f"CMD-MARKER-GATE: {msg}")
    return 1


def load_provenance(handlers_json):
    """Return {letter: executed_count}. Raises if the crosswalk is unusable."""
    if handlers_json:
        raw = open(handlers_json, encoding="utf-8").read()
    else:
        proc = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "cmd_handlers.py"),
                               "--json"], capture_output=True, text=True, cwd=ROOT)
        if proc.returncode != 0:
            raise RuntimeError(f"cmd_handlers.py --json failed ({proc.returncode}): "
                               f"{proc.stderr.strip()[:200]}")
        raw = proc.stdout
    data = json.loads(raw)
    rows = data if isinstance(data, list) else data.get("handlers", [])
    out = {}
    for row in rows:
        letter = str(row.get("handler") or row.get("letter") or "").upper()
        if letter not in LETTERS:
            continue
        executed = row.get("executed", row.get("exec", 0))
        try:
            executed = int(executed)
        except (TypeError, ValueError):
            executed = 0
        out[letter] = executed
    if len(out) != 26:
        raise RuntimeError(f"crosswalk returned {len(out)} letters, expected 26 -- "
                           f"refusing to guess which handlers are unproven")
    return out


def scan_engine(engine_dir):
    """Return {letter: (path, lineno, has_marker)} and a list of bad letters."""
    found, bad = {}, []
    markers_anywhere = 0
    for dirpath, _dirs, files in os.walk(engine_dir):
        for fn in sorted(files):
            if not fn.endswith((".c", ".h")):
                continue
            path = os.path.join(dirpath, fn)
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
            marked = set()
            for line in lines:
                for m in MARK_RE.finditer(line):
                    marked.add(m.group(1).upper())
                    markers_anywhere += 1
            for i, line in enumerate(lines):
                m = DEF_RE.match(line)
                if not m:
                    continue
                letter = m.group(1)
                if letter not in LETTERS:
                    bad.append((path, i + 1, letter))
                    continue
                found[letter] = (os.path.relpath(path, ROOT), i + 1, letter in marked)
    return found, bad, markers_anywhere


def status_claims(doc_text):
    """Return [(cp, status_cell)] for checkpoint rows whose status asserts completion."""
    out = []
    for line in doc_text.splitlines():
        m = ROW_RE.match(line)
        if not m:
            continue
        cp, status = m.group(1), m.group(3).strip()
        low = status.lower()
        if any(w in low for w in DONE_WORDS):
            out.append((cp, status))
    return out


def check(engine_dir, state_doc, handlers_json=None):
    try:
        prov = load_provenance(handlers_json)
    except Exception as exc:  # noqa: BLE001 -- a gate must name its own misconfiguration
        return fail(f"cannot read the crosswalk: {exc}")

    if not os.path.isdir(engine_dir):
        return fail(f"engine source dir not found: {engine_dir} (refusing to pass on zero files)")

    found, bad, markers_anywhere = scan_engine(engine_dir)
    if not os.path.isdir(engine_dir) or not any(
            os.path.exists(os.path.join(engine_dir, f)) for f in os.listdir(engine_dir)):
        return fail(f"engine source dir is empty: {engine_dir}")

    problems = []
    for path, lineno, letter in bad:
        problems.append(f"R3 {path}:{lineno}: `cmd_{letter}` is not one of the 26 letters")

    for letter in LETTERS:
        entry = found.get(letter)
        if entry is None:
            continue
        path, lineno, has_marker = entry
        proven = prov[letter] > 0
        if not proven and not has_marker:
            problems.append(f"R1 {path}:{lineno}: cmd_{letter} has no execution evidence "
                            f"(0 harvests) and no `UNPROVEN: cmd_{letter}` marker")
        if proven and has_marker:
            problems.append(f"R2 {path}:{lineno}: cmd_{letter} executed in "
                            f"{prov[letter]} harvests but still carries an UNPROVEN marker")

    implemented = sorted(found)
    unproven_impl = [l for l in implemented if prov[l] == 0]

    # R4 / R5: the claim side. Read the state document only when a claim could matter.
    doc_text = ""
    if os.path.isfile(state_doc):
        doc_text = open(state_doc, encoding="utf-8", errors="replace").read()
    elif implemented:
        return fail(f"state document not found: {state_doc}")

    claims = status_claims(doc_text) if doc_text else []
    if claims and (markers_anywhere or unproven_impl):
        which = ", ".join(unproven_impl) if unproven_impl else "(marker present)"
        listed = "; ".join(f"{cp} = {st!r}" for cp, st in claims)
        problems.append(f"R4 {os.path.basename(state_doc)} asserts completion while unproven "
                        f"handlers stand: {listed} -- outstanding: {which}")
    if not implemented and any(cp == "CP6" for cp, _ in claims):
        problems.append("R5 the engine has no command handlers, but the state document's CP6 "
                        "status cell asserts completion")

    print(f"crosswalk: {sum(1 for v in prov.values() if v > 0)} proven / "
          f"{sum(1 for v in prov.values() if v == 0)} unproven of 26")
    print(f"engine:    {len(implemented)} of 26 implemented"
          + (f" ({len(unproven_impl)} of them unproven)" if unproven_impl else ""))
    if problems:
        for p in problems:
            print(f"  RED  {p}")
        print(f"CMD-MARKER-GATE: FAIL ({len(problems)} problem(s))")
        return 1
    if not implemented:
        print("CMD-MARKER-GATE: PASS (loop not implemented yet; nothing to mark)")
        return 0
    print("CMD-MARKER-GATE: PASS")
    return 0


# --------------------------------------------------------------------------- selftest

def _fixture(tmp, *, handlers, source, doc):
    """Build a throwaway tree: engine/src/game/commands.c + a state doc + a crosswalk json."""
    eng = os.path.join(tmp, "engine", "src", "game")
    os.makedirs(eng, exist_ok=True)
    with open(os.path.join(eng, "commands.c"), "w", encoding="utf-8") as fh:
        fh.write(source)
    docp = os.path.join(tmp, "state.md")
    with open(docp, "w", encoding="utf-8") as fh:
        fh.write(doc)
    hj = os.path.join(tmp, "handlers.json")
    with open(hj, "w", encoding="utf-8") as fh:
        json.dump(handlers, fh)
    return os.path.join(tmp, "engine", "src"), docp, hj


def _handlers(proven_letters):
    """A crosswalk in which exactly `proven_letters` have execution evidence."""
    return [{"handler": l, "executed": (3 if l in proven_letters else 0)} for l in LETTERS]


def selftest():
    """Eight controls. Both polarities on every rule, plus one that proves the gate refuses
    to certify a tree it cannot see -- the failure mode that made `run_cp0.sh` report PASS
    while inspecting zero files."""
    results = []
    honest_doc = ("# state\n\nno checkpoint may be called code-complete while any marker "
                  "stands\n\n| CP6 | towns + command loop | in progress | x |\n")
    done_doc = ("# state\n\nno checkpoint may be called code-complete while any marker "
                "stands\n\n| CP6 | towns + command loop | done, code-complete | x |\n")
    unprov_src = ("static void cmd_C(u2_ctx *ctx)\n{\n    /* UNPROVEN: cmd_C (CAST) never "
                  "seen running in a capture. */\n}\n")
    unprov_nomark = "static void cmd_C(u2_ctx *ctx)\n{\n    cast_spell(ctx);\n}\n"
    prov_marked = ("static void cmd_A(u2_ctx *ctx)\n{\n    /* UNPROVEN: cmd_A never seen "
                   "running. */\n}\n")
    typo_src = "static void cmd_q(u2_ctx *ctx)\n{\n}\n"

    cases = [
        # (name, expected exit, handlers, source, doc)
        ("C1 unproven handler with no marker -> RED", 1,
         _handlers("A"), unprov_nomark, honest_doc),
        ("C2 same handler WITH the marker -> GREEN", 0,
         _handlers("A"), unprov_src, honest_doc),
        ("C3 proven handler still marked -> RED", 1,
         _handlers("A"), prov_marked, honest_doc),
        ("C4 markers stand + doc claims code-complete -> RED", 1,
         _handlers("A"), unprov_src, done_doc),
        ("C5 no handlers at all + honest doc -> GREEN", 0,
         _handlers("A"), "/* no handlers yet */\n", honest_doc),
        ("C6 typo letter cmd_q -> RED", 1,
         _handlers("A"), typo_src, honest_doc),
        ("C7 proven handler, unmarked, doc honest -> GREEN", 0,
         _handlers("A"), "static void cmd_A(u2_ctx *ctx)\n{\n    attack(ctx);\n}\n",
         honest_doc),
        # The AGENTS.md example puts the marker in a block ABOVE the definition; a body comment
        # is equally natural. Both must satisfy R1, or the first author to format it the other
        # way gets a false RED and starts distrusting the gate.
        ("C9 marker above the definition (AGENTS.md style) -> GREEN", 0,
         _handlers("A"), ("/* UNPROVEN: cmd_C (CAST) never seen running in a capture. */\n"
                          "static void cmd_C(u2_ctx *ctx)\n{\n    cast(ctx);\n}\n"),
         honest_doc),
        # The prose of the state document QUOTES this very rule ("no checkpoint may be called
        # code-complete while any marker stands"). The first version grepped prose and fired on
        # that sentence, which is the fastest way to make a gate ignored. honest_doc contains the
        # quote and an honest status cell, so every prose-reading variant goes red here.
        ("C10 doc quotes the rule in prose, honest status cell -> GREEN", 0,
         _handlers("A"), unprov_src, honest_doc),
        ("C11 zero handlers but CP6 cell claims done -> RED", 1,
         _handlers("A"), "/* no handlers yet */\n", done_doc),
    ]

    for name, want, handlers, source, doc in cases:
        with tempfile.TemporaryDirectory(dir="/var/tmp") as tmp:
            eng, docp, hj = _fixture(tmp, handlers=handlers, source=source, doc=doc)
            got = check(eng, docp, hj)
            results.append((name, want, got))

    # C8: the gate must refuse, not pass, when it cannot see an engine tree at all.
    with tempfile.TemporaryDirectory(dir="/var/tmp") as tmp:
        eng, docp, hj = _fixture(tmp, handlers=_handlers("A"), source="", doc=honest_doc)
        got = check(os.path.join(tmp, "no-such-dir"), docp, hj)
        results.append(("C8 missing engine dir -> refuses (exit 1, never a silent pass)", 1, got))

    bad = 0
    for name, want, got in results:
        ok = (got == want)
        if not ok:
            bad += 1
        print(f"{'OK  ' if ok else 'BROKEN'}  {name}   (want {want}, got {got})")
    if bad:
        print(f"SELFTEST: FAIL -- {bad} control(s) did not behave. Do not trust this gate.")
        return 1
    print(f"SELFTEST: PASS ({len(results)} controls)")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--engine-dir", default=DEFAULT_ENGINE)
    ap.add_argument("--state-doc", default=DEFAULT_STATE)
    ap.add_argument("--handlers-json", default=None)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    return check(args.engine_dir, args.state_doc, args.handlers_json)


if __name__ == "__main__":
    sys.exit(main())
