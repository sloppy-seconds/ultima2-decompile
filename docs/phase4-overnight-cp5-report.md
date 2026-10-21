# Overnight CP5-prep report — 2026-10-22 run

Autonomous run of `docs/phase4-overnight-cp5.md` (T1..T10). Owner asleep; the
contract is *prove or pass*. Statuses: `DONE` / `PASSED — reason` / `BLOCKED — need`.
Grades per `AGENTS.md` § 5: observed / measured / inferred / recalled.

Running log — updated as each task lands. Commit hashes are appended after each
logical commit.

| task | status |
| --- | --- |
| T1 | DONE |
| T2 | todo |
| T3 | todo |
| T4 | todo |
| T5 | todo |
| T6 | todo |
| T7 | todo |
| T8 | todo |
| T9 | todo |
| T10 | todo |

---

## T1 — `tools/cfg_printed.py` silently dropped an executed print site

**Status: DONE.**

### Diagnosis (observed)

Reproduced against the committed capture `captures/spice86/dungeon-35-live`:

```
$ python3 tools/cfg_printed.py captures/spice86/dungeon-35-live --contains LAND
1435 blocks, 136 str_out sites, 4141 executed instructions in this harvest
=== PRINTED (1 sites, call instruction confirmed executed)
  017D:3B5A  'LAND PLANE.'
```

`LAND--NOT HERE!!!!!` (runtime `0x3B72`) is absent, yet its call instruction's
linear address `0x5342` **is** in `ExecutedInstructions` (verified directly).

The site is *not* lost to block discovery — CFG block `017D:3B71` contains the
`call near 0x4FDF` at runtime `0x3B72`. The loss is in `extract()`:

* The inline bytes at file `0x3D75` are `b'LAND--NOT HERE!!!!!\rCMD: \x00...'`.
* `LAND--NOT HERE!!!!!` is terminated by `0x0D` (CR), and the **next** inline
  string `CMD: ` follows before the next `0x00`.
* The old `extract()` split on the first `0x00`, yielding
  `LAND--NOT HERE!!!!!\rCMD: `. The embedded `0x0D` fails the `PRINTABLE`
  regex, so it returned `None` and the site was silently dropped.

This is the exact failure class `AGENTS.md` § 5 warns about: a silent filter
returning a plausible-looking empty result.

### Fix

Rewrote `tools/cfg_printed.py`:

1. **Primary source is now `ExecutedInstructions`.** Print sites are found by
   scanning the executed code-segment instructions for the 3-byte near call
   `E8 <rel16>` whose target resolves to str_out (runtime `0x4FDF`). CFG blocks
   are demoted to a secondary seed, used only for the `--all`
   discovered-but-never-executed list. This matches `AGENTS.md` § 4.
2. **The code segment is derived, not hardcoded** — it is the segment in which the
   str_out entry itself executed. If str_out never ran the tool says so.
3. **`extract()` terminator model fixed.** It now strips leading control markers
   and reads printable bytes up to the *first* non-printable byte, instead of
   splitting on the first NUL and requiring the whole run to be printable. This is
   what dropped `LAND--NOT HERE!!!!!` (terminated by `\r`, followed by `CMD: `).
4. **Fails loudly** rather than returning an empty list when the dump shape is not
   understood: missing/empty `ExecutedInstructions`, entries that are not
   `{Offset,Segment,Linear}` dicts, str_out not executed, zero executed call
   sites, or a CFG that parses to zero blocks (with `--all`). Each prints a
   specific reason and exits non-zero.
5. **Sites with no printable inline message are counted and reported** (e.g. the
   genuine single-char prints `S`, `-` at `0x4881`/`0x4886`), not silently dropped.

### Verification (measured, against committed captures)

* `LAND--NOT HERE!!!!!` (runtime `0x3B72`) is now reported PRINTED in
  `dungeon-35-live`; `LAND PLANE.` (`0x3B5A`) still is.
* Negative controls hold: `MINAX IS DEAD!!`, `RING PROTECTS FROM FIELD!`,
  `FIELD CAUSES 1000 DAMAGE!` appear only under `--all` (discovered, not executed)
  in `dungeon-35-live`, and `RING/FIELD/MAGIC MISSILE/SLEEP SPELL/A THIEF STOLE`
  are correctly PRINTED in `castle-03-live` (matches findings § 12).
* `create-test-live` (creation-only) reports no combat strings — clean negative.
* Output is deterministic across repeated runs (diffed).
* Loud-failure paths exercised with synthetic bad dumps (empty, wrong-shape,
  str_out-not-executed) — each exits non-zero with a specific message.

### Test added

`tools/cfg_printed.py --selftest` runs the built-in positive/negative control
(`LAND--NOT HERE!!!!!` present in `dungeon-35-live`; `MINAX CRIES: DIE FOOL!` and
all combat strings absent there and in `create-test-live`). It SKIPs cleanly (exit
0) when the gitignored captures or `original/ultimaii.exe` are absent, so CI stays
honest. Result: `SELFTEST PASSED`.

Note: captures and `original/` are gitignored, so this test runs offline against
the local working copy, not in CI. That is the same constraint the CP4 screenshot
tests already accept.

### Files

* `tools/cfg_printed.py` (rewritten)
* `docs/phase4-overnight-cp5-report.md` (this file)

`asm/` untouched, so the byte-exact invariant is unaffected. `make -C engine test`
green.

**Commit: `2c2f3c4`.**
