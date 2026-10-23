# 5ABB_view_origin_plain — viewport origin for an INTERIOR sector: same origin, no wrap
# name-evidence: reached from asm/5AB1_view_origin_by_mode when DS:12 != 0xFF. Computes
#           DS:03 = [DS:01] - 6 and DS:02 = [DS:00] - 10 and deliberately does NOT mask,
#           then zeroes DS:04, DS:05, SI and DI. asm/5B98_view_origin_wrapped is the same
#           arithmetic plus `and $0x3f`. Unwrapped means a cell off the edge is off the
#           array rather than wrapped to the far side, which is what a dungeon or tower
#           interior needs and the overworld must not have.
# label: kept as sub_5abb on purpose (CP3 cross-reference anchor).
# func 5ABB..5AE0  len 0026 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28
# confidence: high for the arithmetic
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5abb:
L_005cbb:
        stc
L_005cbc:
        mov    0x1,%al
L_005cbf:
        cmc
L_005cc0:
        sbb    $0x5,%al
L_005cc2:
        cmc
L_005cc3:
        mov    %al,0x3
L_005cc6:
        stc
L_005cc7:
        mov    0x0,%al
L_005cca:
        cmc
L_005ccb:
        sbb    $0x9,%al
L_005ccd:
        cmc
L_005cce:
        mov    %al,0x2
L_005cd1:
        mov    $0x0,%al
L_005cd3:
        mov    %al,0x5
L_005cd6:
        mov    %al,0x4
L_005cd9:
        mov    $0x0,%ah
L_005cdb:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_005cdd:
        mov    $0x0,%ah
L_005cdf:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
