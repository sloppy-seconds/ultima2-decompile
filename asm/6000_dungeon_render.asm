# dungeon_render — the whole first-person frame: depth scan, shapes, sprites, then the three probes
# name-evidence: called only from asm/1151 dungeon_darkness at L_0014cd, and it is the only
#           route to asm/6078 (depth scan), asm/6144 (shape dispatch) and asm/68ED (sprite
#           pass). Renamed 2026-10-29 from dungeon_sample, which described one quarter of it.
#
# CORRECTION 2026-10-29, and it is the correction that unblocked CP7: the header used to say
# the three probes set [DS:23]/[DS:24] to (0,1), ([DS:2],1+[DS:3]) and (-[DS:2],1-[DS:3]),
# read as ABSOLUTE cells. They are not absolute. captures/spice86/dungeon-35-live settles it:
# the player sits at [DS:00]/[DS:01] = (5,5) facing (1,0), and the live bytes read
# [DS:14]=0x10 [DS:15]=0x00 [DS:16]=0x80, which are the cells at (5,5), (6,5) and (4,5) of
# live grid page 0 and no other triple. So the three probes are the cell UNDER, the cell
# AHEAD and the cell BEHIND, and asm/68C0's page arithmetic is applied to the player's own
# coordinates rather than to a small offset. The old reading was inferred from the operand
# bytes alone and the operand bytes are relative deltas; the base is added upstream.
#
# The light gate is the darkness, and it is a byte rather than an inference:
#     cmpb $0x0,0x26 ; je L_00621d
# skips asm/6078, asm/6144 and asm/68ED entirely. With no torch the engine draws nothing at
# all, which is what "IT'S DARK!" means on screen. The three probes below still run.
#
# name-evidence (original): called only from asm/1151 dungeon_darkness (measured). Calls
#           asm/68C0 dungeon_grid_byte three times, storing to [DS:14], [DS:15], [DS:16].
#           three times, storing the results to [DS:14],[DS:15],[DS:16]. This is a DIFFERENT writer
#           of [DS:14] from the overworld walk path (asm/5B71/asm/5C49 mode_table_copy, which sets
#           [DS:14]=[DS:2DF]); the proven [DS:14]=map_byte>>1 belongs to the walk path and is not
#           contradicted here. The y*16+x addressing that looked anomalous against a 64-wide grid is
#           asm/68C0 indexing the 16-wide dungeon grid (see that file's header).
# provenance: measured (asm/6000 body + caller grep + asm/68C0 addressing)
# func 6000..6077  len 0078 B  evidence: reko
# calls: L_006278, L_006344, L_006ac0, L_006aed
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6000:
L_006200:
        nop
L_006201:
        mov    0x2,%al
L_006204:
        mov    %al,0x483
L_006207:
        mov    0x3,%al
L_00620a:
        mov    %al,0x484
L_00620d:
        cmpb   $0x0,0x26
L_006212:
        je L_00621d
L_006214:
        call L_006278
L_006217:
        call L_006344
L_00621a:
        call L_006aed
L_00621d:
        mov    0x2,%al
L_006220:
        mov    %al,0x483
L_006223:
        mov    0x3,%al
L_006226:
        mov    %al,0x484
L_006229:
        mov    0x0,%al
L_00622c:
        mov    %al,0x23
L_00622f:
        mov    0x1,%al
L_006232:
        mov    %al,0x24
L_006235:
        call L_006ac0
L_006238:
        mov    %al,0x14
L_00623b:
        mov    0x0,%al
L_00623e:
        clc
L_00623f:
        adc    0x483,%al
L_006243:
        mov    %al,0x23
L_006246:
        mov    0x1,%al
L_006249:
        clc
L_00624a:
        adc    0x484,%al
L_00624e:
        mov    %al,0x24
L_006251:
        call L_006ac0
L_006254:
        mov    %al,0x15
L_006257:
        mov    0x0,%al
L_00625a:
        stc
L_00625b:
        cmc
L_00625c:
        sbb    0x483,%al
L_006260:
        cmc
L_006261:
        mov    %al,0x23
L_006264:
        mov    0x1,%al
L_006267:
        stc
L_006268:
        cmc
L_006269:
        sbb    0x484,%al
L_00626d:
        cmc
L_00626e:
        mov    %al,0x24
L_006271:
        call L_006ac0
L_006274:
        mov    %al,0x16
L_006277:
        ret
