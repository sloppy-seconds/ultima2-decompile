# dungeon_sprite_pass — walk the per-depth stamp array and draw whatever is standing there
# name-evidence: called only from asm/6000 dungeon_render, after asm/6078 filled [DS:4AF] and
#           asm/6144 drew the geometry. It iterates di = 1..[DS:482], skips a zero stamp, and
#           reads stroke coordinates through word[DS:474], which the live capture of
#           captures/spice86/dungeon-35-live reads as 0x2900 — the DS:2900 stroke table T9.
#           Renamed 2026-10-29 with CP7.
#
# CORRECTION 2026-10-29, same day, and T9 is no longer a gap. The table IS
# `original/monsters`, loaded verbatim at DS:2900 by asm/07F3, and the record framing is
# TWO BYTES, not three. The instruction that hides it is that this routine reads the
# second byte twice from the same pointer and only then advances:
#     b0 -> [DS:04]                    x, and x == 0 ends the list
#     b1 -> [DS:05]    = b1 & 0x1F     y
#     b1 -> [DS:47F]   = b1 >> 5       pattern index   <-- same byte, no advance between
# asm/68A3 scales both by four and asm/4BE0 paints cs:[bp+0x48D4] as a 1..4 pixel run.
# Plotting the file that way yields seven distinct creature silhouettes and an empty
# block 0, which is the confirmation that the framing was right.
#
# The block layout falls out of asm/07F3's CX = 0x800: 2048 bytes is eight blocks of 256.
# Blocks 1..7 each hold ONE full-detail creature, and block 0's tail (0x080..0x0FF) holds
# the depth ladder cs:697E = 00 00 80 C0 E0 F0 F8 FC indexes into: 24 records at 0x080,
# 6 at 0x0C0, 4 at 0x0E0, 2 at 0x0F0, 1 at 0x0F8. Plotted, those are a 6x4 blob, then
# 2x3, 2x2, 1x2, 1x1 — a deliberately typeless simplification series.
#
# So the far arm dropping the type term is the design and not a bug. The nearest creature
# gets its own art; everything further out gets a generic silhouette, because at that size
# the type would not be legible anyway. The near arm's `add ax,[DS:474]` over the stamp
# byte scales by exactly 256, which is what makes block index == dungeon type, and the two
# arms are consistent with each other once the ladder is read as an absolute offset into
# block 0 rather than as a displacement inside the type's block.
# func 68ED..6998  len 00AC B  evidence: call+reko
# calls: L_006aa3, L_006b3a
# provenance: static, read in full 2026-10-29 for CP7. [DS:474] = 0x2900 is read out of
#           captures/spice86/dungeon-35-live's live DS, and the bytes at that address are
#           byte-identical to original/monsters, which is what identifies the table.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68ed:
L_006aed:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_006aee:
        incb   0x482
L_006af2:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006af4:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_006af6:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006af8:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_006af9:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_006afb:
        .byte 0x3a,0x1e,0x82,0x04  # forced-kept: gas re-encodes 'cmp    0x482,%bl' differently
L_006aff:
        jb L_006b02
L_006b01:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
L_006b02:
        .byte 0x8a,0xa5,0xaf,0x04  # forced-kept: gas re-encodes 'mov    0x4af(%di),%ah' differently
L_006b06:
        .byte 0x0a,0xe4  # forced-kept: gas re-encodes 'or     %ah,%ah' differently
L_006b08:
        je L_006af8
L_006b0a:
        .byte 0x83,0xff,0x01  # forced-kept: gas re-encodes 'cmp    $0x1,%di' differently
L_006b0d:
        je L_006b2c
L_006b0f:
        .byte 0xa1,0x74,0x04  # forced-kept: gas re-encodes 'mov    0x474,%ax' differently
L_006b12:
        .byte 0x88,0x26,0x8a,0x04  # forced-kept: gas re-encodes 'mov    %ah,0x48a' differently
L_006b16:
        .byte 0x2e,0x8a,0x85,0x7e,0x69  # forced-kept: gas re-encodes 'mov    %cs:0x697e(%di),%al' differently
L_006b1b:
        .byte 0xa2,0x89,0x04  # forced-kept: gas re-encodes 'mov    %al,0x489' differently
L_006b1e:
        .byte 0xa0,0x8a,0x04  # forced-kept: gas re-encodes 'mov    0x48a,%al' differently
L_006b21:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006b23:
        .byte 0x8a,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bl' differently
L_006b27:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006b29:
        jmp L_006b3a
L_006b2b:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_006b2c:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b2d:
        .byte 0x03,0x06,0x74,0x04  # forced-kept: gas re-encodes 'add    0x474,%ax' differently
L_006b31:
        .byte 0x88,0x26,0x8a,0x04  # forced-kept: gas re-encodes 'mov    %ah,0x48a' differently
L_006b35:
        .byte 0xc6,0x06,0x89,0x04,0x00  # forced-kept: gas re-encodes 'movb   $0x0,0x489' differently
L_006b3a:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006b3c:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_006b3e:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006b40:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b44:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b46:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_006b48:
        jne L_006b4b
L_006b4a:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
L_006b4b:
        .byte 0xa2,0x04,0x00  # forced-kept: gas re-encodes 'mov    %al,0x4' differently
L_006b4e:
        incw   0x489
L_006b52:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b56:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b58:
        .byte 0x24,0x1f  # forced-kept: gas re-encodes 'and    $0x1f,%al' differently
L_006b5a:
        .byte 0xa2,0x05,0x00  # forced-kept: gas re-encodes 'mov    %al,0x5' differently
L_006b5d:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b61:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b63:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b64:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b66:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b67:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b69:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b6a:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b6c:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b6d:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b6f:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b70:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b72:
        .byte 0xa2,0x7f,0x04  # forced-kept: gas re-encodes 'mov    %al,0x47f' differently
L_006b75:
        incw   0x489
L_006b79:
        call L_006aa3
L_006b7c:
        jmp L_006b3a
L_006b7e:
        .byte 0x00,0x00  # forced-kept: gas re-encodes 'add    %al,(%bx,%si)' differently
L_006b80:
        .byte 0x80,0xc0,0xe0  # forced-kept: gas re-encodes 'add    $0xe0,%al' differently
L_006b83:
        .byte 0xf0,0xf8  # forced-kept: gas re-encodes 'lock clc' differently
L_006b85:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # tail-pad
