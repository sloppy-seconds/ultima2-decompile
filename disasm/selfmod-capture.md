# Selfmod cluster — runtime capture (Phase 4 CP0)

Status: **resolved by existing runtime evidence; no live capture needed.**
Regenerators: `tools/selfmod_scan.py`, `tools/selfmod_dump.py`,
`tools/selfmod_diff.py`. Raw scan output is scratch and stays out of git.

## What was asked for

`docs/phase4-plan.md` §1 records a Phase 1/2 finding: the cluster at seg
`0x5120..0x5151` (file `0x5320..0x5351`) was believed to be rewritten at
runtime, so its static bytes were "not the executed logic", and CP0 was to
capture the patched bytes with a one-time memory dump before the engine could
lift the `FOOD=` / `EXP=` status sites inside it.

## Method

No fresh dump was needed. The project already holds 45 Spice86 runtime exports
(`captures/spice86/spice86-cfg.json` plus 44 scenario captures under
`captures/external-20261019/`), and each block records the instruction bytes
the CPU actually executed, not the bytes on disk. `tools/selfmod_scan.py`
rebuilds a runtime-offset -> executed-byte map from all of them and compares
it against `original/ultimaii.exe` at `offset + 0x200`.

**The export demonstrably reflects live memory.** Across 40,958 code blocks and
8,863 distinct observed bytes, exactly two bytes differ from the file image:

| runtime | file | static | executed | meaning |
| --- | --- | --- | --- | --- |
| `+0x0101` | `0x0301` | `41` | `BE` | `mov $0x741,%ax` -> `mov $0x08BE,%ax` |
| `+0x0102` | `0x0302` | `07` | `08` | the MZ loader segment fixup at `asm/0100_sub_0100.asm` |

That is the startup code patching its own data-segment immediate, and `0x08BE`
matches the DS value independently confirmed in `captures/README.md`. A
file-image-only export could not have shown it. So the same comparison is a
valid test for patching anywhere else.

## Result: the cluster is not patched

`python3 tools/selfmod_scan.py --probe 5120-5151` reports 44 of 50 bytes
observed as executed in all 44 scenario captures, **zero differing from the
static image**. The 6 unobserved bytes are `0x5136..0x513B`, which are the
inline string `FOOD=\0` — data, correctly never executed as code.

The executed instruction stream (`tools/selfmod_dump.py --lo 5120 --hi 5151`):

```
off   bytes        executed decode
5120  E8BC02        call near 0x53DF
5123  E87F00        call near 0x51A5
5126  E8B002        call near 0x53D9
5129  B01E          mov AL,0x1E          ; DS:0x2E = column 30
512B  A22E00        mov byte ptr DS:[0x002E],AL
512E  C6062F0015    mov byte ptr DS:[0x002F],0x15   ; DS:0x2F = row 21
5133  E8A9FE        call near 0x4FDF     ; str_out -> "FOOD="
513C  B700          mov BH,0
513E  8A1E5400      mov BL,byte ptr DS:[0x0054]     ; food BCD pair
5142  8BFB          mov DI,BX
5144  A05300        mov AL,byte ptr DS:[0x0053]
5147  0AC0          or AL,AL
5149  7503          jne short 0x514E
514B  E89102        call near 0x53DF
514E  E85400        call near 0x51A5
5151  E88502        call near 0x53D9
```

This is ordinary code: three calls, then the `FOOD=` label at row 21 column 30,
then the food counter. The Phase 1/2 verdict was a static mis-decode, not a
runtime patch — objdump desynchronised across the inline string and produced
garbage (`add %cl,0x541e(%bp,%si)`) where the real stream is the table above.
Phase 3 reconstructed those bytes as-is and byte-proved them, which is why the
bytes are right even though the decode was labelled untrustworthy.

## What the code-segment writes actually are

The asm does write into its own code segment, but never into instructions:

| site | write | nature |
| --- | --- | --- |
| `asm/52CA_timed_wait.asm` | `mov %ah,%cs:0x4f04`, `mov %cx,%cs:0x4f05`, `mov %dx,%cs:0x4f07` | argument staging into a scratch block, read back by `asm/5343_sub_5343.asm` and `asm/535A_sub_535a.asm` |
| `asm/26CC_sub_26cc.asm`, `asm/2708_sub_2708.asm`, `asm/2744_sub_2744.asm` | `mov %cs:0x2798(%di),%al` | data array in the image segment |
| `asm/29D2_sub_29d2.asm` | `mov %cs:0x29d0,%al`, `mov %cs:0x29d1,%al` | two scratch bytes |
| `asm/4B76_pixel_plot.asm`, `asm/4BE0_sub_4be0.asm`, `asm/4C31_sub_4c31.asm` | `mov %cs:0x48d0..0x48dc(...)` | item/shop tables |
| `asm/0A1F_cmd_dispatch.asm` | `mov %cs:0x730(%si),%bx` | read-only command jump table |

The program keeps two variable spaces: the separately allocated DS working
segment (`0x08BE`) and static data living in the loaded image segment next to
the code. The engine models the first in `engine/src/core/state.h` and the
second as cited per-module static state.

## Consequences for Phase 4

* The `FOOD=` / `EXP=` / `GOLD=` sites (`asm/5129`, `asm/5154`, `asm/5175`) are
  liftable straight from `asm/`; CP3 does not depend on a capture.
* The plan's §5 limit "selfmod semantics depend on a one-time runtime capture"
  is retired. Replacement wording: the cluster's executed bytes were verified
  against 45 runtime captures and match the reconstruction.
* The 13 `excluded (selfmod)` dispositions in `asm/` stay as they are — they
  are byte-proven and re-decoding them is a Phase 3 change, out of scope for
  the engine. This note is the record of why they can be lifted safely.

## Honest limits

* The captures are the scenarios recorded on 2026-10-19 (title, shops, death,
  frigate, Lord British, Port Bonifice, and a cumulative watch series). A
  patch that only fires in an uncaptured situation would not show up. The
  cluster's own code runs on the status line, which every gameplay capture
  exercises, so the risk is low but not zero.
* A live DOSBox/Spice86 memory dump would be independent confirmation of the
  same fact. It is not required by any engine checkpoint; ask the owner if they
  want it anyway.
