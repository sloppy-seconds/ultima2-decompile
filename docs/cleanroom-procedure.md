# Cleanroom procedure — substitute tile art

**Purpose.** This is the due-diligence record for `engine/assets/tiles/cleanroom/`. It exists
so that a reviewer, a auditor, or a future maintainer can establish *from evidence in this
repository* that the substitute art was independently authored and is not a reproduction of
Origin's copyrighted Ultima II artwork — and can re-check that claim rather than take it on
trust.

It is an engineering record, not a legal opinion. It documents the controls that were actually
applied, the ones that failed, and what was done about the failures. A procedure that records
only its successes is marketing.

---

## 1. Why this exists at all

The project's own work is Apache-2.0 (`LICENSE`). The game is not ours. `original/` and
`references/` hold the binaries and data, are gitignored, and are never distributed — the
player supplies their own copy.

The engine still needs *something* to draw. Two options were rejected:

* **shipping the game's art** — not ours to distribute, and would make the repository
  unredistributable;
* **no art at all** — the reconstruction would render an empty screen and could not be played
  or tested.

So the project commissions **original substitute art**: drawings that communicate the same
thing at a glance, made by someone who has not looked at the originals. That is the classic
cleanroom pattern, and it only works if the wall is real and provable.

`THIRD-PARTY-LICENSES` records what ships inside the repository; the substitute art is our own
authored work and is listed there as such.

---

## 2. The two roles, and the wall between them

| role | may examine the originals | job |
| --- | --- | --- |
| **spec author** | yes | look at the game's art and the binary, and write down what each tile must *communicate* |
| **implementer** | **no** | draw the substitute from the specification alone |

The wall is between the **implementer** and the **originals**. It is not a wall between the
spec and the evidence — the spec is precisely where the spec author's observations are
supposed to land.

**The rule that makes this auditable:** the specification may carry **intent** but never a
**trace**.

* **Intent** — what the tile must communicate. *"a gateway frame, two posts under a beam,
  bottom centre open."* Many different drawings satisfy it. Drawing one is authorship.
* **Trace** — anything that lets the original be reproduced without looking at it. Pixel
  coordinates, measured densities, cyclic periods, component sizes, ASCII renderings.

Traces live in `docs/tile-art-evidence.md`, which is forbidden to the implementer. If a trace
ever migrates into the spec, the wall becomes decorative, because the implementer can then
reproduce the original arithmetically.

---

## 3. Document inventory — who may read what

| path | implementer | notes |
| --- | --- | --- |
| `docs/tile-art-spec.md` | **allowed** | the only legal input |
| `docs/tile-art-evidence.md` | **forbidden** | measured structure of every original — the answer key |
| `tools/tile_rules.py` | **forbidden** | the gate's bands were fitted to the originals — also an answer key |
| `disasm/tile-art.tsv` | **forbidden** | descriptions written with the originals in view |
| `original/`, `references/`, `tmp/tiles/` | **forbidden** | the game and its extracted art |
| `asm/`, `build/`, `captures/` | **forbidden** | derived from the copyrighted binary |
| `tmp/*.png`, `tmp/*.html` | **forbidden** | screenshots, and the viewer pages which embed extracted art as base64 |
| `engine/assets/tiles/cleanroom/PROVENANCE.md` | **forbidden** | legal record; discusses the originals |
| `/var/tmp/tile-review-ledger.md`, `game-knowledge-deltas.md` | **forbidden** | review notes containing ASCII pixel dumps |

The full list is normative in § 2 of the spec itself. This table is a convenience copy and the
spec wins if they ever disagree.

**Why the answer-key rows matter as much as the art rows.** A gate fitted to one example
encodes that example. `tools/tile_rules.py` contains statements like "diagonals of at least 4"
and "five hollow components of equal size" — enough to reconstruct original structure without
seeing it. The gate is therefore run **against** finished art and never handed to whoever makes
it.

---

## 4. The verification chain — what is actually checked

Each link is a command, not an assertion.

### 4.1 The implementer worked from the current spec

```bash
diff docs/tile-art-spec.md <implementer-repo>/tile-art-spec.md   # must be empty
git hash-object docs/tile-art-spec.md                            # must equal the pinned blob
```

Recorded for revision 2: spec blob `46e0d4d8318e0cfd8529892852b5d8f91342a496`, 24560 bytes,
diff 0 lines.

### 4.2 The imported art is exactly what they committed

```bash
# sha256 every SVG against their repository at its recorded commit
```

Recorded for revision 2: 64/64 byte-identical to `bcfb2e2` in
`/var/home/paul/Projects/ai/ultima-cleanroom`.

### 4.3 The SVGs are generated, not hand-piled

```bash
cd engine/assets/tiles/cleanroom && python3 gen/tiles.py
diff -rq tiles <implementer-repo>/tiles        # must be empty
```

Their `gen/tiles.py` is imported alongside the output, so the set is reproducible from source.
An unexplained pile of SVGs cannot be audited; a generator can.

### 4.4 The art satisfies the structural requirements

```bash
python3 tools/tile_rules.py            # gate; also runs inside `make -C engine test`
```

### 4.5 The shipped header matches the SVGs

```bash
cd engine && python3 tools/tiles2h.py --src assets/tiles/cleanroom/tiles -o /tmp/h.h
cmp /tmp/h.h src/core/tiles_cleanroom.h
```

`make test` fails on drift, and the round-trip is re-decoded through the engine's own
`u2_tile_pixel()` so a packing error cannot hide.

### 4.6 No black is emitted

Black is the backdrop the engine paints, not a tile colour. `tiles2h.py` rejects `#000000`
rather than skipping it, so a tile that broke the palette rule fails loudly.

---

## 5. Build history

### Revision 1 — 2026-10-21

* Spec authored by an agent that had examined the original binary.
* Implemented in a separate repository by a separate agent session.
* **Provenance defects found later, all corrected:**
  * pinned spec blob `f214a89` (the spec's *first* commit) as "the only specification text
    used", but that blob contains no colour-assignment or backdrop section — while the same
    file's verification section asserts those rules. The art was in fact built from
    `c034198`. Proven by blob contents.
  * cited commit `99119e3`, which does not resolve in this repository at all (it belonged to
    the originating repo). Here the set arrived in `b46e5be`.
  * described the letter tiles as "magenta ink on black"; they are `#FFFFFF`.
* **Substantive naming errors inherited by the spec:** art `13` named signpost (it is the
  plane), `14` named spire (rocket), `06` named masonry (an emblem), `0A` named monument (the
  actual signpost), `0B` named arched doorway (a sea monster), `30` named wall (a moongate),
  and eleven tiles named after people that are monster sprites.

### Revision 2 — 2026-10-22

* Spec amended (A1–A17) after the owner reviewed all 64 entries against the extracted
  originals.
* Rebuilt by a separate cleanroom implementer session in its own repository, working from the
  amended spec alone.
* Imported at commit `6376a7e`. Verification chain § 4.1–4.6 all pass.
* Conforming tiles 5 → 17, zero regressions. 47 remain in the pending ledger as visible debt.

---

## 6. Audit trail — controls that failed, and the fix

Recording these is the point of the document. A procedure with no recorded failures has not
been tested.

| # | failure | how found | fix |
| --- | --- | --- | --- |
| 1 | `tools/tile_rules.py` was an unlisted answer key | owner asked "is anything in the spec able to break cleanroom rules?" before more was landed | added to the forbidden list, with the reason written down |
| 2 | the committed A1 amendment cited `asm/`, `spice86-live-findings.md` and `tile-art.tsv` from inside the implementer's only legal document, calling one "the file that records this proof" | same audit | citations stripped; evidence moved to `docs/tile-art-evidence.md` |
| 3 | `PROVENANCE.md` sits in the directory the implementer works in and discusses the originals | same audit | bannered as not-an-implementer-input |
| 4 | `tmp/*.html` embedded extracted art and was not covered by the `tmp/*.png` rule | same audit | added |
| 5 | the gate's `load_grid` silently skipped any `<rect>` carrying an inline `fill`, so a hand-edited SVG would parse as empty and **pass vacuously** | deliberately tampering with a conforming tile and watching the gate stay green | parser fixed to handle both fill placements; re-tampered and confirmed the gate now exits 1 |
| 6 | `inked_cols` was secretly a row check (`any(g[x] for y in ...)` ignores `y`) | making the originals pass their own rules | fixed |
| 7 | `pattern_period` shifted both axes at once, a diagonal test posing as a period test | same | replaced with independent per-axis periods |

Failures 5–7 are the ones worth reading twice: all three were **green-but-meaningless checks**,
which is the worst class of defect in a verification harness because it presents as success.
They were caught only by testing the checker against a known-good input and against a deliberate
break — which is why both are now routine here.

---

## 7. What the gate proves, and what it does not

**Proves:** the finished art satisfies structural requirements stated in the spec — a ring is
hollow, a pass is open at the bottom, a signpost has one crossbar, a letter tile carries its
rules, a repeating tile actually repeats.

**Does not prove:** that the art is good, attractive, or faithful. It cannot see anything.
Judgement of whether a tile *reads* as its subject belongs to the owner, who reviews renders
side by side in `tools/tile_review.py`.

**Also does not prove:** that the implementer did not look at the originals. No technical
control can establish that. What this document establishes is that the *opportunity was
structurally removed* — the implementer worked in a separate repository containing only the
spec, and every path that could have leaked original-derived structure is enumerated in § 3
and was not present in their working tree.

Every rule in the gate is validated by **acceptance**: it must pass the original's structure,
not merely fail the substitute's. A rule that only rejects current art proves nothing; a rule
that accepts the original proves it encodes the described structure, so a clean implementer
can satisfy it from the spec alone.

---

## 8. Known limitations

* **47 of 64 tiles still fail their rules** and are listed in `PENDING_REDRAW`. The set is
  usable and shipped; it is not finished. The debt is printed on every `make test`.
* **The bands were fitted to single examples.** A rule derived from one instance can be too
  tight, so a legitimately different but valid drawing might fail it. The gate is a backstop,
  not the definition of done.
* **Six of the eleven monster sprites have no known name.** They are drawn to a silhouette
  class and left unnamed deliberately, rather than given an invented label.
* **Contested identifications remain open:** `15` (dungeon mouth or sign), `16` (marker or
  sword), `1C` (marsh or otherwise). The spec says so in terms rather than picking a winner.
* **A blind vision model was used to generate hypotheses** during the review. Its output is
  third-party description of the originals and is treated as `recalled` grade only; it stated
  high confidence on all 24 tiles including the wrong ones, so its confidence field carried no
  signal. See `docs/handoff-2026-10-22.md` and the deltas notes.

---

## 9. Reproducing this audit from scratch

```bash
# 1. spec integrity — implementer worked from the current version
diff docs/tile-art-spec.md /var/home/paul/Projects/ai/ultima-cleanroom/tile-art-spec.md
git hash-object docs/tile-art-spec.md

# 2. art integrity — imported files match their committed build
diff -rq engine/assets/tiles/cleanroom/tiles /var/home/paul/Projects/ai/ultima-cleanroom/tiles

# 3. reproducibility — the generator regenerates the set exactly
cd engine/assets/tiles/cleanroom && python3 gen/tiles.py && cd -
git diff --stat engine/assets/tiles/cleanroom/tiles     # must be empty

# 4. structural conformance and the full suite
python3 tools/tile_rules.py
make -C engine test
```

If step 3 leaves a diff, the committed SVGs are not what the generator produces and the chain
is broken — treat that as a provenance incident, not a cosmetic mismatch.

---

## 10. Statement

The substitute tile art in `engine/assets/tiles/cleanroom/` was authored by a separate
implementer working from `docs/tile-art-spec.md` alone, in a repository that contained no game
art and no derived descriptions of it. The specification was written by a different role that
had examined the originals, and is constrained to state intent rather than transcribe traces.
The chain from spec to committed art is reproducible with the commands in § 4 and § 9, and the
failures found along the way are recorded in § 6 rather than removed from the record.

No claim is made that the art is a good likeness, or that the procedure is proof against an
implementer who looked anyway. The claim is narrower and checkable: the opportunity to copy was
removed, the artefacts are reproducible, and the checks that matter have been demonstrated to
fail when they should.
