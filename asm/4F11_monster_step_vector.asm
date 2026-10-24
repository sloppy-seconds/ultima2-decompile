# monster_step_vector — DS:19/DS:1A := the clamped one-cell step toward the player
# name-evidence: per axis, `stc ; mov al,[DS:00] ; sub al,[di+0x137] ; add al,al ;
#           add al,al ; call L_0052d8` and store to DS:19 (DS:01 / [di+0x157] / DS:1A).
#           asm/50D8_sign_of_al returns -1/0/+1, so the stored value is a unit step,
#           not a distance. This is the value asm/212E adds to mon_x/mon_y.
# WHY THE x4: sign(4*d) is not sign(d). 4*d overflows the signed byte at |d| >= 32,
#           which is exactly half the 64-cell grid, so the doubling-in-place is what
#           makes the vector take the SHORT WAY ROUND the torus rather than the long
#           way. Measured over all 4096 (player_x, mon_x) pairs: the result equals the
#           shortest torus direction in 3904 of them; the 192 exceptions are the two
#           near cells each axis (the -1 below) and the exact antipode.
# THE -1, and it is load-bearing: `stc` sets CF and x86 `sub` subtracts CF, so the
#           difference is player - mon - 1, not player - mon. asm/152E and asm/0B0F
#           both write `stc ; cmc` before their subtract, which cancels it; this
#           routine does not. Consequence, derived not observed: on each axis the
#           creature reaches the player's cell only from the high side (mon = player+1,
#           step -1); from the low side it parks one cell short. See
#           docs/contract-creature-tick.md and docs/needs-gameplay.md G28.
# reached from: asm/0AA7 calls asm/4F36_monster_pursuit_vector first (the raw delta,
#           used by the asm/0AAA special-attack distance test), then every path through
#           the special dispatch joins at asm/0AFC, which calls THIS routine.
# func 4F11..4F1F  len 000F B  evidence: seed+call+reko
# provenance: static, decoded 2026-10-28 with the x4/overflow model checked in code
# confidence: high for the bytes and the clamp; medium for the torus reading (it is an
#           arithmetic consequence of the bytes, not a separately observed behaviour)
# label: kept as sub_4f11 on purpose — labels are body and CP0 md5s them
# calls: L_0052d8
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f11:
L_005111:
        stc
L_005112:
        mov    0x0,%al
L_005115:
        sub    0x137(%di),%al
L_005119:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00511b:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00511d:
        call L_0052d8
