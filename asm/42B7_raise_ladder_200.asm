# raise_ladder_200 — second rung: HP below 7500 raises 200
# name-evidence: `bl = 2` then `cmp $0x75,%al ; jb` to asm/42D1. Reached only by falling through
#           from asm/42AA, so it means "not below 0x50, but below 0x75". Observed live at the
#           transition 5101 -> 5301 and eleven more times.
# func 42B7..42C0  len 000A B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: live:lord-british-tribute, static
# confidence: high
# label: sub_42b7 / L_0044b7 kept as they are — labels are body (AGENTS.md § 3).
sub_42b7:
L_0044b7:
        mov    $0x0,%bh
L_0044b9:
        mov    $0x2,%bl
L_0044bb:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044bd:
        cmp    $0x75,%al
L_0044bf:
        jb L_0044d1
