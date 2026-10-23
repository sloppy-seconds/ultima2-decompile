# monster_pursuit_vector — DS:19/DS:1A := player cell minus this creature's cell
# name-evidence: `mov al,[DS:00]; sub al,[di+0x137]; mov [DS:19],al` and the same
#   pair for DS:01 / [di+0x157] / DS:1A. Plain `sub`, no wrap adjust, so the delta
#   is the direct difference and can go negative (it is read as signed by
#   asm/50EF at the caller).
# called from: the per-slot creature loop asm/0A6D..0AB5, once per non-empty slot,
#   immediately before asm/0AAA tests |DS:19| < 3 and |DS:1A| < 3 for the special
#   attack gate. The same pair is the move delta in asm/212e, so one vector drives
#   both the strike decision and the step. asm/152E computes the same delta with a
#   torus wrap through asm/50D8.
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
