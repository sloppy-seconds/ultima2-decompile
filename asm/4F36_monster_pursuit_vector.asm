# monster_pursuit_vector — DS:19/DS:1A := the raw pursuit delta, unclamped
# name-evidence: `stc ; mov al,[DS:00]; sub al,[di+0x137]; mov [DS:19],al` and the same
#   pair for DS:01 / [di+0x157] / DS:1A. No clamp and no wrap adjust, so the delta can go
#   negative (it is read as signed by asm/50EF at the caller).
# CORRECTION 2026-10-28, three claims this header used to make.
#   (1) It IS the plain difference. An earlier version of this header said the `stc` made it
#       player - creature - 1. Wrong: x86 `SUB` does not subtract CF, only `SBB` does, so the
#       `stc` is a dead instruction — a translated 6502 `SEC ; SBC`, where the SEC was needed
#       on the 6502 and is merely harmless here. Measured live, 20/20 trials, in
#       captures/spice86/g28-pursuit.
#   (2) asm/212E does not use this routine's value. Every path through the special-attack
#       dispatch joins at asm/0AFC, which calls asm/4F11 and overwrites DS:19/DS:1A with the
#       clamped -1/0/+1 step before asm/212E reads them. What THIS routine feeds is the
#       magnitude tests in asm/0AAA and asm/1040, not the step.
#   (3) asm/152E is not a torus variant. It clamps through asm/50D8_sign_of_al and does no
#       wrap; the torus behaviour is the `add al,al` pair in asm/4F11.
# called from: the per-slot creature loop asm/0A6D..0AB5, once per non-empty slot,
#   immediately before asm/0AAA tests |DS:19| < 3 and |DS:1A| < 3 for the special
#   attack gate. asm/152E is the dungeon-side variant and clamps through asm/50D8_sign_of_al.
# provenance: live:g28-pursuit, static. The bytes are static (tools/check_func.py). The
#           no-clamp finding — that DS:19/DS:1A carry the raw signed difference and that the
#           leading `stc` is a dead instruction left over from a translated 6502 `SEC ; SBC` —
#           was measured live over 20/20 trials in captures/spice86/g28-pursuit, and the 6502
#           side corroborates it independently: the ancestor's equivalent needs the SEC, the
#           x86 port kept the flag set and dropped the subtract-with-borrow.
# func 4F36..4F4C  len 0017 B  evidence: seed+call+reko
# apple2-twin: $406F in STD.SUBS.OBJ, reached from the JMP vector $4003. `SEC ; LDA $00 ;
#           SBC $4D00,X ; STA $17` and the y pair — the raw delta with no clamp and no x4,
#           which is exactly what this file is. CORROBORATED, not observed; it does not rename
#           anything. The SEC here is also the witness that settles the retraction below: on
#           the 6502 `SEC` before `SBC` is *required* for a plain subtract (SBC computes
#           A - M - 1 + C), so the DOS `STC` before `SUB` is a faithful translation of a pair
#           that needed the flag over there and does not need it here — both sides compute the
#           plain difference. Found via tools/apple2_anchor_map.py.
# confidence: high (four stores, no ambiguity)
# label: kept as sub_4f36 on purpose — labels are body and CP0 md5s them
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f36:
L_005136:
        stc
L_005137:
        mov    0x0,%al
L_00513a:
        sub    0x137(%di),%al
L_00513e:
        mov    %al,0x19
L_005141:
        stc
L_005142:
        mov    0x1,%al
L_005145:
        sub    0x157(%di),%al
L_005149:
        mov    %al,0x1a
L_00514c:
        ret
