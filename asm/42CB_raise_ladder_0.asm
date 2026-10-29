# raise_ladder_0 — bottom rung: at or above 9900 the tribute raises nothing
# name-evidence: `bl = 0`, reached by falling through asm/42C1's `jb` when [DS:51] is not below
#           0x99. Observed live: HP 9901 stayed 9901 while gold still fell 7349 -> 7299.
# func 42CB..42D0  len 0006 B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: live:lord-british-tribute, static
# confidence: high
# notes: this rung is an OVERFLOW GUARD. A +100 on a high byte of 0x99 would carry past a packed-
#           decimal byte and corrupt the field, so refusing to raise is the correct behaviour and
#           the reason HP never exceeds 9999. Do not "fix" it into a smaller raise.
# label: sub_42cb / L_0044cb kept as they are — labels are body (AGENTS.md § 3).
sub_42cb:
L_0044cb:
        mov    $0x0,%bh
L_0044cd:
        mov    $0x0,%bl
L_0044cf:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
