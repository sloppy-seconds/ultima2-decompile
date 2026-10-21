# vehicle_board_dispatch — BOARD: picks which vehicle to mount, by vehicle code
# name-evidence: [DS:14] compared against 0x22/0x24/0x26/0x28, each branch jumping
#           into asm/2FD6 (horse), asm/2FFE (ship), asm/3038 (frigate),
#           asm/3048 (plane) or the rocket tail of the latter
# func 2FAD..2FB3  len 0007 B  evidence: seed+reko
# provenance: live:airport-castle — reached from asm/2F6F (cmd_B) via asm/2F9E,
#           which loads DS:23/24 from DS:00/01 and calls asm/50B3 (map_tile_ptr).
# notes: the code space is shared with the riding state at [DS:13], which the
#           callees overwrite: 0x22 horse, 0x24 ship/frigate, 0x26 PLANE, 0x28
#           rocket. asm/38B0 (cmd_L, LAUNCH) then tests [DS:13] for 0x26 and 0x28,
#           and landing a plane is accepted only on tile 0x08 (grass) — anything
#           else prints 'LAND--NOT HERE!!!!!'.
# OPEN, do not model as settled: [DS:14] is NOT the raw map byte. Every byte in
#           every mapx file is a multiple of 4, and 0x22 and 0x26 occur zero times
#           across all 33 sectors, so the vehicle codes cannot be file bytes. The
#           plane tile is map byte 0x34 (art index 13, which decodes to an
#           aeroplane) while the plane vehicle code is 0x26, so a transform exists
#           and it is unproven. [DS:14] is written at file 0x6238 from a call to
#           0x6AC0 and saved/restored at 0x5D74 and 0x5E4C.
# confidence: medium (dispatch table and riding state proven; the tile->code
#           transform is not)
sub_2fad:
L_0031ad:
        mov    0x14,%al
L_0031b0:
        cmp    $0x22,%al
L_0031b2:
        je L_0031d6
