# minax_proximity_check — Minax strikes from up to four cells away
# name-evidence: tests mon_type == 0x40, then |mon_x - player_x| < 4 and
#   |mon_y - player_y| < 4 via asm/50EF (abs of a signed byte), then calls
#   L_00118e = asm/0F8E_combat_minax_attack. Type 0x40 is Minax: the art index is
#   type>>2 (docs/art-index.md) and 0x40>>2 == 0x10, the tile asm/0F8E's own note
#   identifies as Minax by bitmap identity.
# reached from: the creature move routine at asm/218b, and only when [DS:4A] != 0
#   (the sector's second digit). asm/218b is reached both when a creature's
#   candidate cell is the player's cell and when all three candidate moves were
#   refused, so this check runs for blocked creatures too, not only adjacent ones.
# not: the general monster attack. Contact with the player produces no attack at
#   all — see docs/monster-spawn.md § 13, which is also the correction of the
#   "0x1240 sits in a gap" note that blocked CP5 W6 for a session.
# func 1040..1047  len 0008 B  evidence: seed+reko
# confidence: medium (the branch and the callee are bytes; the Minax identity is
#   third-party art matching plus our own type>>2 rule)
# label: kept as sub_1040 on purpose — labels are body and CP0 md5s them
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1040:
L_001240:
        mov    0x197(%di),%al
L_001244:
        cmp    $0x40,%al
L_001246:
        jne L_00126d
