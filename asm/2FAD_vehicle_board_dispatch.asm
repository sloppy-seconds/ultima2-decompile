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
# ---------------------------------------------------------------------------
# RESOLVED 2026-10-29: the four arms are gated on ITEMS, and the tail refuses with the
#           game's own words instead of falling through silently. Read as a whole, the
#           dispatch is:
#
#             0x22 horse   -> asm/2FD6            no gate
#             0x24 ship    -> asm/2FF6 gate       DS:E2 == 0 -> asm/2FFE (refusal)
#                                                   DS:E2 != 0 -> asm/3038 (board, mode 0x24)
#             0x26 plane   -> asm/3048 at 0x3259  DS:DF == 0 -> 'STRANGE YOU CAN'T GET IN!'
#                                                   DS:DF != 0 -> board, mode 0x26
#             0x28 rocket  -> asm/3048 at 0x32a9  prints ' ROCKET' FIRST, then
#                                                   DS:DD == 0 -> 'YOU MUST HAVE AN ANKH!'
#                                                   DS:DD != 0 -> board, mode 0x28
#             anything else-> asm/2FB8: call str_out ' WHAT?' ; jmp L_000c30
#
#           so BOARD on ordinary ground prints the line "BOARD WHAT?". Nothing had to be
#           invented, which is the question the handoff asked before writing a refusal.
#           THE GATE BYTES ARE ITEM SLOTS. DS:DD, DS:DF, DS:E1, DS:E2 and DS:E5 are
#           items_held[7], [9], [11], [12] and [15] (items_held is DS:D6..DS:E5, sixteen
#           slots), and the item name table at file 0x501D names those slots ANKH, SKULL
#           KEY, BRASS BUTTON, BLUE TASSLE and TRI-LITHIUM. Each refusal names its own item
#           in the game's words, so the mapping is five independent agreements rather than
#           an inference: 'YOU MUST HAVE AN ANKH!' behind DS:DD, 'STRANGE YOU CAN'T GET IN!'
#           behind DS:DF, 'THE CREW OF THIS SHIP WILL NOT LET YOU BOARD!' behind DS:E2, and
#           from asm/38B0 'MISSING A BRASS BUTTON!' behind DS:E1 and 'SHIP INCAPABLE OF
#           LAUNCH!' behind DS:E5.
#           EVERY SUCCESSFUL ARM ALSO WRITES THE CELL. asm/2FD6 and asm/3048's plane and
#           rocket tails write 0x08 (grass) and asm/3038 writes 0x00 (water), each through
#           the cached cell pointer (`mov 0x6,%bx` then `mov %al,(%bx)`). Boarding therefore
#           consumes the vehicle tile and does not move the player. The live agreement is
#           captures/spice86/ship-port-boniface, where [DS:14] read 0x24 on the ship tile
#           and 0x00 immediately after BOARD with the position unchanged.
#           Grade: bytes for the writes, one measured live sample, and INFERRED that [DS:6]
#           holds the player's own cell at this moment — asm/5AFF computes that pointer from
#           coordinates and which coordinates are current here was not traced. Note the
#           handoff's "the ship tile was still 0x48 after boarding" is the map FILE read
#           back from disk, not live memory; the live read says otherwise.
# confidence: high for the dispatch and the item gates, medium for the cell write's target
sub_2fad:
L_0031ad:
        mov    0x14,%al
L_0031b0:
        cmp    $0x22,%al
L_0031b2:
        je L_0031d6
