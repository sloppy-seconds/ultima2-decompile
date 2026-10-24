# Fragment-split detector

`tools/fragment_splits.py` finds routines that the Phase 3 mechanical clean wave cut into
pieces. `disasm/fragment-splits.tsv` is its generated output — **regenerate it, do not
edit it**, per `AGENTS.md` § 3 (a derived view that is hand-kept is worse than none).

```bash
python3 tools/fragment_splits.py            # summary
python3 tools/fragment_splits.py --tsv --all > disasm/fragment-splits.tsv
python3 tools/fragment_splits.py --selftest # controls, run before believing anything
```

## Why this exists

The clean wave gave every CFG-discovered basic block its own `asm/` file and its own row
in `disasm/function-map.tsv`. That yields a correct byte proof and a wrong function map.
The shape of a victim: a run of adjacent fragments, each ending on a branch into the next,
only the first with an inbound `call`, exactly one `ret` in the whole run.

It was found by hand in the commerce region (`docs/g22-split-proposal.md`, merged under
the owner's ruling as `2028..2051`, `2052..20AA`, `20AB..2121`), and then the identical
shape turned up again, unrelated, while decoding a number printer: `51A5/51A9/51AE` and
`53B5/53C5` were two routines drawn as five files. Hand-discovery only finds what you
trip over.

## The rule

Row B, immediately after row A, is **glued** to A when: nothing `call`s any address in B;
every jump landing in B comes from A, from inside B, **or from code the run can already
reach**; and A does not terminate on its own (no `ret`, and no unconditional `jmp` out of
the A+B span).

A glued run is a **candidate** only with **exactly one `ret`, in the last row**. `strong`
if the first row has an inbound `call`, `probable` if not — the entry may be a jump-table
slot, and this game reaches its command handlers with `jmp *%bx`, which is invisible
statically (`AGENTS.md` § 4).

## The clause that earns its keep (2026-10-28d): loops

The reachability clause in the second bullet is not a refinement, it was a bug shaped like a
definition. Read literally — "every jump landing in B comes from A or from inside B" — the
rule **rejects loops**, because a loop is precisely a later fragment branching back to an
earlier one, and that jumper is neither A nor inside B.

The case that proved it: `asm/06AC_clock_tick_wait`, decoded by hand on 2026-10-28 byte by
byte as one 65-byte routine with three backward branches. The detector, on the literal rule,
reported it as **two** runs (`06A8..06AB` and `06CC..06EC`) and missed the middle entirely.
A hand reading that the tool contradicted is the shape of failure this project keeps hitting,
and here the tool was the wrong one.

Fix: a jumper counts as third-party only if it is not reachable from the run's own entry,
where reachability follows fallthrough and jumps and **stops at a `ret`** — that stop is what
keeps it from swallowing the whole segment. Effect: **26 strong / 17 probable became 36 strong
/ 10 probable**, eight of the new strong candidates being loop-shaped routines the literal
rule could never have found, including the clock wait and the step gate below.

Two of those are now positive controls, and one is a negative:

* `06AC..06EC` must come back as **one** run of 11 fragments.
* `2199..21F7` must come back as one run of 18. Its own header has carried the hand reading
  since 2026-10-28, so the detector agreeing is independent confirmation — and where it
  disagrees is instructive: the step gate has **two** returns (accept at `21F7`, refuse at
  `21FC`), so the one-`ret` rule cuts the run at the first. The detector's span is not wrong,
  it is narrower than the routine. Anyone merging from this TSV has to notice that.
* `50B3` (`map_tile_ptr`, 26 inbound calls, the most-shared helper in the tree) must **never**
  be absorbed into a neighbour. It is the control that says the relaxation did not become a
  licence to glue anything downstream.

## The condition that earns its keep

The first version graded anything glued as a candidate and produced **277** runs, which is
not a finding, it is a shrug. Requiring exactly one `ret` in the last row cut that to
**45** (28 strong, 17 probable) and it did so for a reason.

The case that forced it: `1799..17DC` — the commerce print chain — came back as a
candidate and was wrong. Four fragments, **no `ret` anywhere**: a sequence of message
printers that tail into each other and return somewhere else entirely. Real, and worth
knowing about, but a different claim from "this was one function". Those 232 runs are now
counted separately as `tail-chains` and not reported as candidates.

**The selftest caught this before it was ever cited.** `1799` is a named negative control
and the run went `SELFTEST: FAIL (1)`. That is the `AGENTS.md` discipline working — a gate
that cannot go red is worse than a tool that lies, and this gate went red on its own first
draft.

## Controls

| | case | why |
| --- | --- | --- |
| positive | `50F9` | spot-checked 2026-10-23, 25 fragments one ret, still unmerged |
| positive | `4A3E` | 7 fragments, still unmerged |
| positive | `06AC..06EC` | the clock wait — proved one routine by hand first; the loop control |
| positive | `2199..21F7` | the step gate — header carries the hand reading; the two-return case |
| negative | `15E1` tavern menu | standalone routine |
| negative | `1799` food price | a tail-chain, not a split |
| negative | `2028`, `2052`, `20AB` | merged 2026-10-23; if these come back the detector is keying on something other than the split it already fixed |
| negative | `51A5`, `53B5` | merged 2026-10-23, same |
| negative | `50B3` map_tile_ptr | 26 inbound calls; the reachability relaxation must not absorb a shared helper |

All eleven pass. The `2199` control was written wrong on the first attempt — it asked for
`21FB`, which is a row *end*, not a row *start* — and the selftest went red on my own bad
control before it ever went green. That is the intended behaviour of a control list, and it
is worth recording precisely because it was the tool catching me, not the other way round.

## Reading the output

**A candidate is a nomination, not a ruling.** `AGENTS.md` § 3 says a boundary change needs
the owner, and `docs/harness-portability.md` § 6 records why: a boundary is a claim about
intent and the bytes support it only sometimes. Merging also has a cost — it moves body
lines between files, which is exactly what `engine/tests/asm_body_guard.py` exists to
police.

### Merging is not concatenation — but it is solvable, and the tree already knew (2026-10-28d)

An attempt was made to merge `06AC..06EC` — eleven fragments, the clock-tick wait, span
verified byte by byte and confirmed by this tool the same day. The first attempt failed, and
the first write-up of it here said *structurally unmergeable*. **That was wrong**, and the
correction is more useful than the original claim.

Two separate obstacles were tangled together, and only one of them is real.

**Obstacle 1 — mine, not the tree's.** `disasm/function-map.tsv` still declared `06AC` as a
4-byte function, so `check_func` refused on length: `body assembled 65 B, map says 4 B`. The
map is Phase 2 output and it is part of the merge procedure. All three sanctioned merges
(`21a86bf`, `4644eb9`, `a98ec94`) edited it: the surviving row takes the full span and the
absorbed rows are deleted. I did not, and then blamed the guards for my own omission. Preflight
rule: a merge touches **both** `asm/` and the map, or it has not been done.

**Obstacle 2 — real, and narrow.** Each fragment carries its own `clock_int1a:` seam label,
because each was a separate compilation unit and `tools/clean_wave.py` emits one per `int`
site. Concatenated into one unit, jwasm refuses: `symbol 'clock_int1a' is already defined`.

Commenting the two duplicate label lines fixes it, and the fix is **provable rather than
argued**, because a bare label emits no bytes. Tested end to end in a throwaway worktree, with
`original/` symlinked in and the repo never touched:

    check_func 06AC                       PASS 06AC clock_tick_wait [65 B]
    assemble_clean.sh                     CLEAN REBUILD BYTE-MATCH: 37344 bytes identical

The only gate that objects is `engine/tests/asm_body_guard.py`, at 26,080 -> 26,078 lines.
Its objection is correct as written — a label line is body — but the thing it protects is byte
conservation, and `assemble_clean.sh` proves byte conservation directly and more strongly.
So this is a policy question about the guard's scope, not an impossibility, and it belongs to
the owner rather than to an agent who wants their own work to pass.

**The scope is small, and it was measured, not guessed.** Enumerating the seam labels of all 36
strong runs: **33 merge today with the proven procedure and no policy change at all.** Only
three collide, and they collide on two names:

    06AC..06EC   11 frags   clock_int1a x3
    4A3E..4A73    7 frags   video_int10 x3
    5003..505E   10 frags   video_int10 x2

The narrow ruling on offer is therefore: may `asm_body_guard` accept the removal of a
**duplicate** seam label — one of the four names in `clean_wave.py`'s `INT_SEAM` map — when at
least one copy survives in the merged unit? That is mechanically checkable and enumerable, and
it is not a bless mode: it permits one provably zero-byte class of change and nothing else.

The forward fix needs no ruling and touches no existing line. `clean_wave.py` should number the
seam label per site (`video_int10`, `video_int10_2`, …) so that a routine with three `int` sites
has three distinct symbols and a future merge never collides. That is a change to how the tree
is *generated*, which is allowed; rewriting the tree that was already generated is the part that
needs the owner.

Two things to check on any candidate before proposing it:

1. **Run length.** `50F9..51A4` is 25 fragments over 172 bytes, mostly 1- and 2-byte basic
   blocks with the single `ret` at the end. That is one routine cut into blocks, and it is
   fine. But a long run is also where a wrong merge does the most damage, so read the whole
   span, not the first fragment.
2. **Whether a "split" is actually several small routines that happen to fall through.**
   `19D7..2027` is the standing example: four shop handlers, each ending in a tail jump,
   where any boundary is a judgement the bytes do not assert. The detector deliberately
   does not propose splitting, only merging, and even merging needs the span read.

## Status

**Three merges executed 2026-10-23 under the owner's ruling**, all verified by
`asm_body_guard` (content conserved), `check_func`, `assemble_clean.sh` (37344 B identical)
and `make -C engine test`:

| merged span | from | result |
| --- | --- | --- |
| `4050..40A5` | 13 fragments | `cmd_T` — the TRANSACT ray |
| `51A5..51AF` | 3 fragments | `print_bcd4_al_di` — four-digit BCD emitter |
| `53B5..53CF` | 3 fragments | `print_byte_bcd` — two-digit emitter |

`asm/` is now 1271 files, down from 1300 at the start of the day. Candidates remaining:
**36 strong, 10 probable** (was 26/17 before the loop clause — the extra strong candidates
are not new damage, they are the loops the old rule could not see).

**The controls had to be re-pointed, and that is the lesson.** `51A5` and `53B5` were the
positive controls. Merging them made the selftest fail — correctly, because they were no
longer candidates. A positive control that has been fixed is worse than none, since it
fails for the right reason forever and trains everyone to ignore it. They moved to the
negative list and `50F9` / `4A3E` were promoted as positives, both still unmerged.
**Re-point the positives whenever you merge.**

One more thing the guard caught that is worth recording: it refused the first attempt at
the printer merges with `+22 body lines`, because I had created the merged files and not
deleted the originals, so two files claimed the same start address. That is the guard
earning its existence on an operator error, not a design error.
