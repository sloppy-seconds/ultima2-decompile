# monster_pursuit_vector — DS:19/DS:1A := the raw pursuit delta, unclamped
# name-evidence: `stc ; mov al,[DS:00]; sub al,[di+0x137]; mov [DS:19],al` and the same
#   pair for DS:01 / [di+0x157] / DS:1A. No clamp and no wrap adjust, so the delta can go
#   negative (it is read as signed by asm/50EF at the caller).
# CORRECTION 2026-10-28, two claims this header used to make.
#   (1) It is NOT the plain difference. The `stc` sets CF and x86 `sub` subtracts CF, so the
#       stored value is player - creature - 1. asm/152E and asm/0B0F both write `stc ; cmc`
#       to cancel it; this routine does not. See asm/4F11_monster_step_vector.
#   (2) asm/212E does not use this routine's value. Every path through the special-attack
#       dispatch joins at asm/0AFC, which calls asm/4F11 and overwrites DS:19/DS:1A with the
#       clamped -1/0/+1 step before asm/212E reads them. What THIS routine feeds is the
#       magnitude tests in asm/0AAA and asm/1040, not the step.
# called from: the per-slot creature loop asm/0A6D..0AB5, once per non-empty slot,
#   immediately before asm/0AAA tests |DS:19| < 3 and |DS:1A| < 3 for the special
#   attack gate. asm/152E is the dungeon-side variant and clamps through asm/50D8_sign_of_al.
# func 4F36..4F4C  len 0017 B  evidence: seed+call+reko
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
