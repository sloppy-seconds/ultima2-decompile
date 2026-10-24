# speed_faster_f7 — F7 raises the game speed by 0x200, capped at 0x3a00
# name-evidence: reached from asm/4FA0 (`cmp $0x7300,%ax`, the INT 16h extended scancode for F7).
#           Body: `mov 0x74,%ax ; add $0x200,%ax ; cmp $0x3a00,%ax ; ja <skip> ; mov %ax,0x74`,
#           then falls through to asm/4FB3_speed_rescale_call. The mirror of
#           asm/4F8E_speed_slower_f8, which subtracts and floors at DS:554 instead.
# the ceiling is a literal, the floor is a variable: 0x3a00 = 14,848 is encoded in the
#           instruction, while the lower bound is read from DS:554 at run time. So the top of the
#           speed range is fixed in the binary and the bottom is data — which is why the startup
#           measurement in asm/06AC_clock_tick_wait can legitimately land above 0x3a00 (it did:
#           0x3A17 in captures/spice86/g30-clockcal/) without anything clamping it away.
# provenance: static, decoded 2026-10-28d from the listing; bytes proven by tools/check_func.py
# confidence: high for the arithmetic; medium for the F7 label itself (standard scancode meaning,
#           not a string this binary prints)
# label: kept as sub_4fa5 on purpose — labels are body and CP0 md5s them
# func 4FA5..4FB2  len 000E B  evidence: seed+reko
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fa5:
L_0051a5:
        mov    0x74,%ax
L_0051a8:
        add    $0x200,%ax
L_0051ab:
        cmp    $0x3a00,%ax
L_0051ae:
        ja L_0051b6
L_0051b0:
        mov    %ax,0x74
