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
every jump landing in B comes from A or from inside B; and A does not terminate on its own
(no `ret`, and no unconditional `jmp` out of the A+B span).

A glued run is a **candidate** only with **exactly one `ret`, in the last row**. `strong`
if the first row has an inbound `call`, `probable` if not — the entry may be a jump-table
slot, and this game reaches its command handlers with `jmp *%bx`, which is invisible
statically (`AGENTS.md` § 4).

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
| positive | `51A5/51A9` | decoded by hand 2026-10-23, certainly one routine |
| positive | `53B5/53C5` | same |
| negative | `15E1` tavern menu | standalone routine |
| negative | `1799` food price | a tail-chain, not a split — the case above |
| negative | `2028`, `2052`, `20AB` | merged 2026-10-23; if these come back the detector is keying on something other than the split it already fixed |

All seven pass.

## Reading the output

**A candidate is a nomination, not a ruling.** `AGENTS.md` § 3 says a boundary change needs
the owner, and `docs/harness-portability.md` § 6 records why: a boundary is a claim about
intent and the bytes support it only sometimes. Merging also has a cost — it moves body
lines between files, which is exactly what `engine/tests/asm_body_guard.py` exists to
police.

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
**26 strong, 17 probable**.

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
