# pixel_plot — set one pixel to colour 3 at ([DS:479]+[DS:4BF], [DS:47A]+[DS:4C1])
# name-evidence: the tail-call target of asm/67B3 line, and its body is CGA mode-4 chain-4
#           addressing: `and $3` picks the plane mask from cs:0x48D0 (c0 30 0c 03), `shr $1`
#           twice gives the byte offset x>>2, and the row SEGMENT comes from cs:0x48DC indexed
#           by y. Renamed 2026-10-29 with CP7.
#
# Two facts worth having cold, both measured rather than assumed:
#   * ORing the plane mask sets BOTH plane bits, so this routine can only ever write colour 3
#     (white). asm/4BAA is the same address arithmetic with the mask inverted and writes
#     colour 0. The dungeon wireframe is white lines on black because these are the only two
#     pens.
#   * The row table is NOT a flat 40-bytes-per-row framebuffer: entry y is 0xB800 + (y/2)*5
#     for even y and 0xBA00 + ((y-1)/2)*5 for odd y, i.e. two 8000-byte fields 40 bytes per
#     row, which is CGA interlace (even field B800, odd field BA00). The engine's frame is a
#     flat 320x200 and the view is plotted 1:1 into it, which is what the origin pair allows.
#   * [DS:4BF] and [DS:4C1] are the origin, and nothing in the tree writes them; the live
#     capture of dungeon-35-live reads both as 16. So the view's own space — x 0..0xFF from
#     the XL/XR tables, y 0..0x7F from YT/YB — lands on a 256x128 rectangle inset 16 pixels.
#     That is the mapping game/dungeon.c uses, and this byte pair is its whole evidence.
#
# Other callers (asm/2B65, asm/6B3D, asm/6D83) show it is a general primitive and not a
# dungeon routine; the dungeon is just the first consumer this project has decoded.
# func 4B76..4BA9  len 0034 B  evidence: call+reko
# provenance: static, read in full 2026-10-29 for CP7. The row-segment table at cs:0x48DC and
#           the plane-mask table at cs:0x48D0 were read out of original/ultimaii.exe at file
#           0x4ADC and 0x4AD0; the origin pair [DS:4BF]/[DS:4C1] = 16/16 is read out of
#           captures/spice86/dungeon-35-live's live DS.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b76:
L_004d76:
        push   %es
L_004d77:
        mov    $0x0,%ah
L_004d79:
        mov    0x479,%al
L_004d7c:
        add    0x4bf,%ax
L_004d80:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004d82:
        mov    $0x0,%ah
L_004d84:
        mov    0x47a,%al
L_004d87:
        add    0x4c1,%ax
L_004d8b:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_004d8d:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004d8f:
        .byte 0x81,0xe3,0x03,0x00  # forced-kept: gas re-encodes 'and    $0x3,%bx' differently
L_004d93:
        shr    $1,%di
L_004d95:
        shr    $1,%di
L_004d97:
        shl    $1,%si
L_004d99:
        mov    %cs:0x48dc(%si),%ax
L_004d9e:
        mov    %ax,%es
L_004da0:
        mov    %cs:0x48d0(%bx),%al
L_004da5:
        or     %al,%es:(%di)
L_004da8:
        pop    %es
L_004da9:
        ret
