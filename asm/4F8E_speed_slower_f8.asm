# speed_slower_f8 — F8 lowers the game speed by 0x200, floored at DS:554
# name-evidence: reached from asm/4F89 (`cmp $0x7400,%ax`, the INT 16h extended scancode for F8).
#           Body: `mov 0x74,%ax ; sub $0x200,%ax ; cmp 0x554,%ax ; jb <skip> ; mov %ax,0x74`,
#           then falls to asm/4FB3 which calls the rescaler. So DS:74 is not inert scratch, it is
#           a **user-settable speed variable**, and DS:554 is its floor.
# the pair: asm/4FA5_speed_faster_f7 is the other direction (F7, +0x200, ceiling 0x3a00). Both
#           converge on asm/4FB3_speed_rescale_call, so every keypress recomputes the 20 delay
#           slots at DS:580 from the new DS:74. That is the consumer asm/06AC_clock_tick_wait was
#           missing: the startup measurement seeds this same variable, and the keys override it.
# bounds, and why the measured value sits outside them: the ceiling 0x3a00 = 14,848 applies only
#           to the key handler's arithmetic. The live reading from captures/spice86/g30-clockcal/
#           was DS:74 = 0x3A17 = 14,871 — 31 above the key ceiling — which is exactly what a
#           startup measurement that no clamp ever touched should look like.
# provenance: static, decoded 2026-10-28d from the listing; bytes proven by tools/check_func.py.
#           The scancode-to-key mapping (0x7400 = F8, 0x7300 = F7) is the standard INT 16h
#           extended set, and docs/phase4-implementation.md independently recorded two function
#           keys adjusting DS:74 by ±0x200 within these same bounds.
# confidence: high for the arithmetic and the bounds; medium for the key labels themselves, which
#           are the standard scancode meaning rather than a string this binary prints
# label: kept as sub_4f8e on purpose — labels are body and CP0 md5s them
# func 4F8E..4F9F  len 0012 B  evidence: seed+reko
# calls: L_0051b3
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f8e:
L_00518e:
        mov    0x74,%ax
L_005191:
        sub    $0x200,%ax
L_005194:
        cmp    0x554,%ax
L_005198:
        jb L_0051b6
L_00519a:
        mov    %ax,0x74
L_00519d:
        jmp L_0051b3
L_00519f:
        nop
