# sprite_stroke — scale one stroke record and hand it to the pixel block
# name-evidence: called only from asm/68ED dungeon_sprite_pass, once per stroke record,
#           and its whole body is three loads and two shifts:
#               bp = [DS:47F]            the pattern index (record byte 1 >> 5)
#               ax = [DS:04] * 4         x, scaled by four
#               bx = [DS:05] * 4         y, scaled by four
#               call asm/4BE0
#           The x4 is what makes the sprite a block drawing rather than a point plot:
#           combined with asm/4BE0's `di = (x + origin) >> 2` the two cancel for the
#           byte column and the pattern table picks the sub-pixel, so one record paints
#           a run of one to four pixels. Renamed 2026-10-29 when the sprite framing was
#           read; body untouched.
# func 68A3..68BF  len 001D B  evidence: call+reko
# calls: L_004de0
# provenance: static, read in full 2026-10-29 with asm/68ED and asm/4BE0 as one chain.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68a3:
L_006aa3:
        nop
L_006aa4:
        mov    $0x0,%ah
L_006aa6:
        mov    0x47f,%al
L_006aa9:
        .byte 0x8b,0xe8  # forced-kept: gas re-encodes 'mov    %ax,%bp' differently
L_006aab:
        mov    0x4,%al
L_006aae:
        shl    $1,%ax
L_006ab0:
        shl    $1,%ax
L_006ab2:
        mov    $0x0,%bh
L_006ab4:
        mov    0x5,%bl
L_006ab8:
        shl    $1,%bx
L_006aba:
        shl    $1,%bx
L_006abc:
        call L_004de0
L_006abf:
        ret
