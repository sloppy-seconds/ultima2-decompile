# Phase 4 — Acceptance criteria, derived from the artifacts

## 0. Why this file exists

Acceptance criteria for a checkpoint should be **derivable from the artifacts we
own**, not recalled by the owner after the fact. When the owner has to describe
how the game behaves, that is a signal that a branch was stubbed or skipped
without saying so — which happened at CP3: `P` ran the demo, `D` ran only part of
the poem, and the intro's dragon screen was silently absent. All three were
derivable from `asm/` before a single line was written.

So this file states the method, the standing gate rule, and the criteria derived
so far. Where a criterion is genuinely a product decision rather than a fact about
the binary, it is listed as such instead of being quietly invented.

## 1. Method — how a criterion is derived

1. **Find the entry point.** The jump table, the dispatch chain, or a `call` site
   in an already-decoded function. Cite the file offset.
2. **Decode that function.** `asm/` first. If the region is `db` blobs, run
   `tools/redecode.py --func asm/NNNN_*.asm` and read the listing.
3. **Read the seams it touches.** Every DOS `int 21h` goes through the wrapper at
   `asm/52CA`, which takes the function number in AH from its caller — so look
   for `mov ah,$NN` before `call $0x54ca`, and for the 8-byte FCB name inline
   after the call. That is how disk I/O is identified.
4. **State what the player observes**, not what the code does internally: which
   screen, which keys, what changes on disk.
5. **Cross-check against the shipped content** in `references/ultima2/` (read-only
   fallback) and `captures/` where a live dump exists.
6. **Mark confidence.** `proven` = the code says it directly. `inferred` = a
   consistent reading with a named gap. `not derivable` = a product decision.

A criterion is only evidence-backed if a reader could re-derive it from the cited
offset. "It seems like the game would..." is not a criterion.

## 2. Standing gate rule (owner-directed, 2026-10-27)

**Before a checkpoint is called done, audit every user-reachable branch against
its asm entry point and record, per branch: "asm says X, engine does Y".**

This includes branches that were *not* implemented. The audit is cheap — the `P`
miss above was ten seconds of reading a decode that had already been produced —
and it is the only control that catches "tests green, game wrong". Passing engine
tests prove determinism and internal consistency; they say nothing about whether
the engine behaves like the game.

The audit goes in `docs/phase4-implementation.md` for the checkpoint, in this
table format.

## 3. Derived criteria — title menu (CP1/CP3 territory)

Menu dispatch, file `0x059B..0x05A6`:

```
059B  jmp  $0x5af        ; 'D' -> demonstration (asm/03AC body)
059E  cmp  al,$0x50 ; je $0x5ac   ; 'P' -> call $0x964 (asm/0764)
05A2  cmp  al,$0x43 ; je $0x5a9   ; 'C' -> call $0x5600 (asm/5400)
05A6  jmp  $0x442                  ; anything else -> redraw the title
```

| branch | asm says (proven unless noted) | engine today | gap |
| --- | --- | --- | --- |
| **D** | Disk dance (`call 0x964`), clear, story flag `DS:239=1`, then **six poem couplets, each accompanied by a 16 KB picture load**: `PICOUT` `0x5c3`, `PICTWN` `0x63d`, `PICCAS` `0x6ba`, `PICDNG` `0x72a`, `PICSPA` `0x7a7`, `PICMIN` `0x825` (all `CX=0x4000`, matching the shipped 16384-byte files) | Shows the first poem block only | **pictures not rendered at all** (CP9); 1 of 6 couplets. The one-couplet scope is the owner's call; the missing pictures are a known deferral, not a decision |
| **P** | Read 256 bytes into `DS:36`; if `DS:36 != 0` continue into the game (`0x9E6`), else print `(INSERT PLAYER DISK)` and wait for ESC, then retry | Matches, then shows an overworld placeholder | world is CP4 |
| **C** | Full generation form; write the record; then `INSERT PROGRAM MASTER` and restart the program | Form matches; returns to the main menu | restart-vs-menu is a **mapping decision** (no disk to swap), recorded as a deliberate deviation |
| other | Redraw the title | Matches | — |
| intro | Third presentation screen loads `PICDRA` at file `0x41a` (read at `0x40F..0x417`) — the dragon screen | Text screens only | **pictures not rendered** (CP9). This was silently absent rather than flagged; that is the process failure, not the deferral |

### What is *not* derivable from the artifacts

Listed so it stays visible instead of being filled in silently:

- **How much of a deferred feature to fake for now.** "Show the first line of the
  poem" is a scope decision. The artifacts say the demo has six couplets and six
  pictures; they cannot say how much of that to build this week.
- **Which deferral order is right.** CP9 for bitmaps is a plan choice, not a fact
  about the binary.
- **Anything about feel or polish** — timings, holds, colour, whether a placeholder
  text is acceptable.

The rule for these: **state the gap and ask, rather than pick quietly.** A silent
substitution is what made a stub look like a finished feature.

## 4. Known limits of this method

- `asm/` is byte-exact but not behaviour-reviewed; five functions are still `db`
  blobs, and `asm/8387` turns out to be data misclassified as a function.
- A linear disassembly walks through data, so a decode can be misaligned. The
  re-decode tool collapses inline strings to help, but a listing is a reading aid
  and `asm/` remains ground truth.
- The runtime captures cover the paths that were executed. Unexecuted branches
  have no dynamic evidence at all.
- **Determinism is not correctness.** The replay evidence proves a run reproduces;
  it cannot tell you the run was the right one. That is exactly the blind spot
  that produced the CP3 misses.
