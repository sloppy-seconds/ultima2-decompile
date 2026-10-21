# vehicle_board_dispatch — BOARD: picks which vehicle to mount, by vehicle code
# name-evidence: [DS:14] compared against 0x22/0x24/0x26/0x28, each branch jumping
#           into asm/2FD6 (horse), asm/2FFE (ship), asm/3038 (frigate),
#           asm/3048 (plane) or the rocket tail of the latter
# func 2FAD..2FB3  len 0007 B  evidence: seed+reko
# provenance: live:flight-launched-live, flight-32-live — BOARD, ' PLANE',
#           'LAUNCH--PLANE' and 'LAND PLANE.' are all in the executed print set of
#           the 2026-10-21 sector-32 airfield session, and [DS:13] was read as 0x26
#           while mounted and 0x22 on a horse.
# notes: the code space is shared with the riding state at [DS:13], which the
#           callees overwrite: 0x22 horse, 0x24 ship/frigate, 0x26 PLANE, 0x28
#           rocket. asm/38B0 (cmd_L, LAUNCH) then tests [DS:13] for 0x26 and 0x28.
# RESOLVED 2026-10-21, was OPEN: [DS:14] = map_byte >> 1. Measured live on 53 of
#           54 walk samples across four terrain bytes (0x0C->0x06, 0x5C->0x2E,
#           0x70->0x38, 0x08->0x04). So the vehicle map bytes are 0x44 horse,
#           0x48 ship, 0x4C PLANE, 0x50 rocket, i.e. arts 0x11/0x12/0x13/0x14,
#           which are this project's own horse, frigate and rocket candidates in
#           disasm/tile-art.tsv - three independent corroborations of the mapping.
# CORRECTION: an earlier version of this header said the plane tile was 0x34. It
#           was wrong: a render used %02d against hex-named tile PNGs, so art 0x13
#           was displayed under the label "13" and attached to the wrong byte.
#           0x34 is art 0x0D, a humanoid figure with arms raised. The game itself
#           settles it: BOARD on a 0x4C tile set [DS:13] = 0x26 and printed
#           ' PLANE', and LAUNCH then ran the plane sequence.
# landing: 'LAND PLANE.' is accepted only on tile 0x08 (grass); anything else
#           prints 'LAND--NOT HERE!!!!!' and inertial flight continues. Both
#           branches executed in captures/spice86/flight-launched-live
#           (runtime 0x3B5A and 0x3B72, gate cmp at 0x3B56).
# still open: the [DS:14] writer at file 0x6238 calls 0x6AC0, whose index
#           arithmetic came out as y*16 + x against a 64-wide grid. Unexplained.
# confidence: medium (dispatch table and riding state proven; the tile->code
#           transform is not)
sub_2fad:
L_0031ad:
        mov    0x14,%al
L_0031b0:
        cmp    $0x22,%al
L_0031b2:
        je L_0031d6
