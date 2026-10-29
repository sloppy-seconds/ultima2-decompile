# dungeon_step_vector — dungeon-side step vector: DS:19/DS:1A := sign(player - creature), no off-by-one
#           (`stc ; cmc` cancels CF before the sbb, unlike asm/4F11_monster_step_vector).
#           Reached only from asm/1151_dungeon_turn, the dungeon side of the split.
#           asm/212E on the overworld path uses asm/4F11 instead, and the difference is the
#           whole point: asm/4F11 doubles the difference twice before taking its sign, and
#           that x4 is what makes an overworld creature take the short way round a 64x64
#           TORUS. A 16x16 dungeon page has edges and no wrap, so doubling would be a
#           bug here. No `add al,al` pair in this file is the evidence, not an omission.
#           Engine twin: u2_dungeon_creatures() in engine/src/game/dungeon.c.
# func 152E..154D  len 0020 B  evidence: call+reko
# calls: L_0052d8
# provenance: static, decoded 2026-10-29 for G54; the no-doubling contrast with asm/4F11
#           is the finding, and the engine twin is u2_dungeon_creatures().
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_152e:
L_00172e:
        nop
L_00172f:
        mov    0x0,%al
L_001732:
        stc
L_001733:
        cmc
L_001734:
        sbb    0x137(%di),%al
L_001738:
        call L_0052d8
L_00173b:
        mov    %al,0x19
L_00173e:
        mov    0x1,%al
L_001741:
        stc
L_001742:
        cmc
L_001743:
        sbb    0x157(%di),%al
L_001747:
        call L_0052d8
L_00174a:
        mov    %al,0x1a
L_00174d:
        ret
