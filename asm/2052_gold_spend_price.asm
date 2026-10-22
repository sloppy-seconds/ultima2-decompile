# gold_spend_price — charge the BCD price pair DS:27/28 against gold DS:58/59
# name-evidence: subtracts [DS:27]:[DS:28] from [DS:58]:[DS:59] with the
#           cmc;sbb;das;cmc decimal-subtract idiom, and the fall-through branch
#           prints 'YOU DONT HAVE THAT MUCH!'. Five inbound callers:
#           15E1_tavern_menu, 1869_cleric_shrine, 19D7_magic_shop_menu,
#           3C2E_cmd_O, 4282_sub_4282.
# func 2052..20AA  len 0059 B  evidence: seed+call+reko
# strings: "YOU DONT HAVE THAT MUCH!"
# calls: L_0051df (str_out), L_000c30
# provenance: static; the affordable branch was observed executing on 2026-10-23
#           when a real purchase took gold 9999 -> 9987 (captures/spice86/armour-buy)
# confidence: high for the arithmetic and for which branch is which (bytes plus a
#           live purchase); see the DOUBT block below for what is still read, not known.
#
# MERGED 2026-10-23 from the fragments 2052, 2070, 20A4 and 20A7, per
# docs/g22-split-proposal.md § 2 with the owner's approval. The four were one
# routine cut on branch targets by the mechanical clean wave; the only `ret` in the
# whole span 19D7..2140 that terminates this one is at 20AA, and 2052 is the only
# inbound call target in the first three. Body lines are unchanged and in address
# order -- engine/tests/asm_body_guard.py proves it.
#
# HOW IT WORKS (observed, byte-level)
#   2052  stc; cmc                      clear carry, then the chained subtract
#         sbb [DS:28] from [DS:59], das, cmc
#         sbb [DS:27] from [DS:58], das, cmc
#   206E  jb  20A7        <-- AFFORDABLE. The trailing cmc inverts the borrow, so
#                         CF=1 means NO borrow. Gold has already been reduced by
#                         the trial subtract, so 20A7 just sets AL=0 and returns.
#   2070  (fall-through, cannot afford) adds the pair back and prints the refusal.
#   20A4  jmp L_000c30    the refusal does not return to the caller; it goes back
#                         to the command loop.
#
# DOUBT -- read this before citing the routine
#   * The branch polarity was stated BACKWARDS in an earlier pass on 2026-10-23
#     (the failure path was described as the `jb` target). Corrected the same day
#     by simulating the exact instruction sequence: 9999-0200 -> 9799 taken,
#     9959-0040 -> 9919 taken, 0020-0200 not taken, 0004-0005 not taken. The
#     simulation is a model, not the CPU; it agrees with one live purchase.
#   * The two exits are asymmetric and the reason is inferred, not proven. The
#     affordable path returns normally with AL=0; the refusal path does `pop %ax`
#     at 2087 -- discarding its own return address -- and then tail-jumps to
#     L_000c30. Reading: a refused purchase abandons the caller entirely and goes
#     back to the prompt. Plausible, and consistent with what the game does after
#     a failed buy, but nothing here proves the caller expects to never come back.
#   * `pop %ax` at 2087 sits immediately before a `call`, which is an odd pairing.
#     It may be a deliberate stack discard or it may be mis-decoded data that
#     happens to assemble. check_func.py proves the BYTES round-trip; it does not
#     prove the disassembly is the intended instruction. Treat as unresolved.
#   * On the refusal path the trial subtract briefly leaves the BCD-underflow value
#     in gold (0004-0005 writes 0x9999) before the add-back restores it. Observed
#     in simulation, never in a live dump. Do not describe it as a user-visible bug.
#   * Which of DS:27/DS:28 is the high byte is taken from asm/2052's own pairing
#     against DS:58/DS:59, and docs/commerce.md § 3b. It is consistent everywhere
#     it has been checked but the field names in engine/src/core/state.h
#     (gold_lo at 0x58) read the opposite way and are about ADDRESS order, not
#     significance. Do not infer byte order from those names.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2052:
L_002252:
        nop
L_002253:
        stc
L_002254:
        mov    0x59,%al
L_002257:
        cmc
L_002258:
        sbb    0x28,%al
L_00225c:
        das
L_00225d:
        cmc
L_00225e:
        mov    %al,0x59
L_002261:
        mov    0x58,%al
L_002264:
        cmc
L_002265:
        sbb    0x27,%al
L_002269:
        das
L_00226a:
        cmc
L_00226b:
        mov    %al,0x58
L_00226e:
        jb L_0022a7
sub_2070:
L_002270:
        clc
L_002271:
        mov    0x59,%al
L_002274:
        adc    0x28,%al
L_002278:
        daa
L_002279:
        mov    %al,0x59
L_00227c:
        mov    0x58,%al
L_00227f:
        adc    0x27,%al
L_002283:
        daa
L_002284:
        mov    %al,0x58
L_002287:
        pop    %ax
L_002288:
        call L_0051df
        db "YOU DONT HAVE THAT MUCH!",0x00        # string
sub_20a4:
L_0022a4:
        jmp L_000c30
sub_20a7:
L_0022a7:
        nop
L_0022a8:
        mov    $0x0,%al
L_0022aa:
        ret
