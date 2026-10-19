# Command Jump Table (CP2)

**Output:** `disasm/jump-table.txt` — 26 lines, `XXXX handler=<letter>`, where `XXXX` is the
`cs:` offset stored in the table (file offset = `XXXX + 0x200`).

## How the table was located (independently, from `original/` + `captures/`)

1. Scanned every `jmp` record in `captures/spice86/spice86-cfg.json` for an indirect jump.
   Exactly one block contains `jmp near BX` (`FFE3`): block 2193, entry `017D:0A1F`.
2. The block's code is the command dispatcher:

   ```
   0A1F: F9        stc
   0A20: F5        cmc
   0A21: 1C 41     sbb  al, 0x41      ; al = key - 'A'
   0A23: 02 C0     add  al, al        ; *2  -> word index
   0A25: B4 00     mov  ah, 0
   0A27: 8B F0     mov  si, ax
   0A29: 2E 8B 9C 30 07  mov bx, cs:[si+0x0730]   ; 26-entry word table at cs:0x0730
   0A2F: FF E3     jmp  bx
   ```

3. Table base: `cs:0x0730` -> file `0x0730 + 0x200 = 0x930`. Read 26 little-endian words.
   All entries are monotonic in `0x2B8F..0x4568` (inside code space), confirming the table.

## Plausibility check (all 26)

`objdump -d -b binary -m i8086 -j .data` at each `XXXX+0x200`: **24/26 handlers begin with
`call 0x51df`** (the shared inline-string display routine — consistent with the documented
calling convention where the message bytes follow the `call`); the remaining two (`L`=38B0,
`V`=437E) begin with `mov al, abs` (reading a game-state byte). No handler decodes as
mid-string garbage. All 26 pass.

## Cross-check vs `entry-points.txt` — gap explanation

Only **7 of 26** jump-table targets appear in `disasm/entry-points.txt` (E, N, P, Q, R, S, T).
The other 19 are **not in the runtime CFG at all** — not dropped by the dead rule, not inside
any executed block, no block starts within ±0x40. The captured playthrough simply never
pressed those keys. This is the documented single-playthrough limitation
(`phase1-plan.md` §6: "Code never executed is absent"); broader re-capture is deferred to
Phase 2 by the plan.

| Present in CFG | Absent from CFG |
| --- | --- |
| E N P Q R S T | A B C D F G H I J K L M O U V W X Y Z |

The 19 absent handlers are still first-party evidence-backed entry points (the table itself is
ground truth for where a handler starts), so they are seeded into the decompilers via the union
seed file used by CP4/CP5 (see implementation log).
