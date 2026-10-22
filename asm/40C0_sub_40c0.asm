# sub_40c0 — reads [DI+0x1D7] and branches on bit 7 (TRANSACT-path fragment, unnamed on purpose)
# func 40C0..40C7  len 0008 B  evidence: seed+reko
# confidence: medium (bytes proven by check_func.py; meaning inferred from cmd_O)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# caller: asm/4050_cmd_T.asm:103 `jne L_0042c0` — the only reference in the tree.
#         This file is a fragment of the cmd_T flow and a fragment_splits merge
#         candidate; it is deliberately NOT renamed to a cmd_T_* name until that
#         merge happens, so the filename stays address-first.
# reads: [DI+0x1D7] the per-slot role/scripted-identity byte (DI = cursor slot).
#        bit 7 set -> falls through to asm/40C8 (jmp L_004409); bit 7 clear ->
#        asm/40CB, which then tests [DI+0x197] (creature type) against 0x6c.
# meaning: bit 7 separates "slot has a scripted response" from an ordinary creature.
#        Evidence is NOT in this fragment: asm/3C2E_cmd_O enumerates the high values
#        0x81/0x82/0x83 into ENILNO / the RING / a third recipient, asm/2C38 writes
#        0x84 with `SHE'S GONE!!!`, and asm/102B tests the slot for zero. See
#        docs/monster-spawn.md § 6. The owner's aggro-marker reading is not
#        supported by any consumer found so far.
sub_40c0:
L_0042c0:
        mov    0x1d7(%di),%al
L_0042c4:
        cmp    $0x80,%al
L_0042c6:
        jb L_0042cb
