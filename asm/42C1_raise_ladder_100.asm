# raise_ladder_100 — third rung: HP below 9900 raises 100
# name-evidence: `bl = 1` then `cmp $0x99,%al ; jb` to asm/42D1. Observed live at 7501 -> 7601
#           and twenty-three more times, which is the rung that carries HP from 7501 to 9901.
# func 42C1..42CA  len 000A B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: live:lord-british-tribute, static
# confidence: high
# label: sub_42c1 / L_0044c1 kept as they are — labels are body (AGENTS.md § 3).
sub_42c1:
L_0044c1:
        mov    $0x0,%bh
L_0044c3:
        mov    $0x1,%bl
L_0044c5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044c7:
        cmp    $0x99,%al
L_0044c9:
        jb L_0044d1
