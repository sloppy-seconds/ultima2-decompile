# pixel_block — paint one pattern byte into a 2x2 block of video bytes
# name-evidence: called only from asm/68A3 sprite_stroke. ax = x, bx = y, bp = pattern:
#           `di = (ax + [DS:4BF]) >> 2` is the video byte column (four pixels per byte at
#           2bpp), `cl = cs:[bp+0x48D4]` is the sub-pixel mask, and the four stores write
#           cl at [di] and [di+0x50] in each of the two segments cs:[bx*2+0x48DC] and
#           cs:[bx*2+0x48DE]. Those two table entries are the even and odd field of the
#           same row pair, and +0x50 is 80 bytes = two rows of 40, so one call paints a
#           short horizontal run two scanline-pairs tall. Renamed 2026-10-29 with the
#           sprite decode; body untouched.
#           The mask table cs:48D4 = ff 11 88 cc 33 00 00 00, so pattern 0 lights all four
#           sub-pixels and patterns 5..7 light nothing at all — which is why the record
#           terminator is a zero X byte and not a zero pattern.
# provenance: static, read in full 2026-10-29 alongside asm/68A3 and asm/68ED; the two
#           tables it indexes were read out of original/ultimaii.exe at file 0x4AD4 and
#           0x4ADC.
# func 4BE0..4C1D  len 003E B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4be0:
L_004de0:
        push   %ax
L_004de1:
        push   %bx
L_004de2:
        push   %bp
L_004de3:
        push   %cx
L_004de4:
        push   %di
L_004de5:
        push   %es
L_004de6:
        add    0x4bf,%ax
L_004dea:
        shr    $1,%ax
L_004dec:
        shr    $1,%ax
L_004dee:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004df0:
        mov    %cs:0x48d4(%bp),%cl
L_004df5:
        add    0x4c1,%bx
L_004df9:
        shl    $1,%bx
L_004dfb:
        mov    %cs:0x48dc(%bx),%ax
L_004e00:
        mov    %ax,%es
L_004e02:
        mov    %cl,%es:(%di)
L_004e05:
        mov    %cl,%es:0x50(%di)
L_004e09:
        mov    %cs:0x48de(%bx),%ax
L_004e0e:
        mov    %ax,%es
L_004e10:
        mov    %cl,%es:(%di)
L_004e13:
        mov    %cl,%es:0x50(%di)
L_004e17:
        pop    %es
L_004e18:
        pop    %di
L_004e19:
        pop    %cx
L_004e1a:
        pop    %bp
L_004e1b:
        pop    %bx
L_004e1c:
        pop    %ax
L_004e1d:
        ret
