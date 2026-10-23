# 4326_unlock_target — the cell UNLOCK tests: (x + DS:19, y), no Y term
# name-evidence: `mov 0x1,%al ; mov %al,0x24` puts DS:24 at the player Y unchanged, and
#           `mov 0x0,%al ; clc ; adc 0x19,%al ; mov %al,0x23` puts DS:23 at player X plus
#           DS:19. Then `call L_0052b3` (asm/50B3_map_tile_ptr) fetches the live grid cell
#           at (DS:23, DS:24) and leaves the cell pointer in DS:06 for asm/435E to write.
# The handoff called this computation "only partly read" and asked for it to be read before
# another capture. It is read now: there is no vertical aim, and the earlier guess that the
# target was "the adjacent cell in the facing direction" was wrong in the Y axis.
# label: kept as sub_4326 on purpose (CP3 cross-reference anchor).
# func 4326..4339  len 0014 B  evidence: seed+reko
# calls: L_0052b3
# provenance: static reassembly 2026-10-28
# confidence: high
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4326:
L_004526:
        mov    0x1,%al
L_004529:
        mov    %al,0x24
L_00452c:
        mov    0x0,%al
L_00452f:
        clc
L_004530:
        adc    0x19,%al
L_004534:
        mov    %al,0x23
L_004537:
        call L_0052b3
