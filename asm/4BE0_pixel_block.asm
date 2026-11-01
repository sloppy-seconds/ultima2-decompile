# pixel_block — paint one CGA 2bpp colour byte into a 4x2 pixel block of video memory
# name-evidence: called only from asm/68A3 sprite_stroke. ax = x, bx = y, bp = pattern:
#           `di = (ax + [DS:4BF]) >> 2` is the video byte column (four pixels per byte at
#           2bpp), `cl = cs:[bp+0x48D4]` is the byte stored, and the four stores write
#           cl at [di] and [di+0x50] in each of the two segments cs:[bx*2+0x48DC] and
#           cs:[bx*2+0x48DE]. Those two table entries are the CGA bank segments — they hold
#           0xB800 and 0xBA00 at runtime — and +0x50 is 80 bytes = one row of 320/4, so one
#           call paints four pixels across and two scanlines down. Renamed 2026-10-29 with
#           the sprite decode; body untouched.
#           CORRECTION 2026-11-01, same routine, two claims retracted. cs:[bp+0x48D4] is
#           NOT a sub-pixel mask. The stores are unconditional — `mov %cl,%es:(%di)` with
#           no AND and no OR — so in 320x200 mode 4 the byte IS four pixels' colour values,
#           two bits each, and the pattern index selects a COLOUR, not a shape. Decoded:
#             ff -> white,white,white,white   11 -> black,cyan,black,cyan
#             88 -> magenta,black,magenta,black
#             cc -> white,black,white,black   33 -> black,white,black,white
#             00 x3 -> black (erase)
#           So patterns 5..7 do not "light nothing", they paint black, and a sprite erases
#           as well as draws. This is why a dungeon creature is a cyan body with a magenta
#           mouth: the creature blocks in `original/monsters` use patterns 0..5, and 1 and 2
#           are cyan and magenta. Confirmed against the live frame, which carries exactly
#           three colours — (170,170,170) wireframe, (0,170,170) body, (170,0,170) mouth.
# provenance: static, read in full 2026-10-29 alongside asm/68A3 and asm/68ED.
#           The earlier provenance line said the two tables were read out of
#           original/ultimaii.exe at file 0x4AD4/0x4ADC and is retracted twice over: the
#           bias is wrong (cs:48D4 is file 0x46D4), and more importantly the static bytes
#           there are e8 08 0b 58 2d 49 54 00, which are NOT the ff 11 88 cc 33 the routine
#           uses. The table is SELF-MODIFIED at startup. The runtime values were read at
#           linear 0x17D0+0x48D4 and are identical across six independent captures
#           (cp5-weak2, edge32, sweep28, jester3, art-index, shipcap3), which is what makes
#           this observed rather than inferred.
# func 4BE0..4C1D  len 003E B  evidence: call+reko
# confidence: medium (bytes proven by check_func.py; the colour reading is observed at runtime)
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
