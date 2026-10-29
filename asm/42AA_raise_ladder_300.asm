# raise_ladder_300 — top rung of the tribute ladder: HP below 5000 raises 300
# name-evidence: `mov 0x51,%al` then `bl = 3` then `cmp $0x50,%al ; jb` to the store in asm/42D1.
#           [DS:51] is the HIGH packed-decimal byte of HP, so the compare is "HP below 5000" and
#           the raise of 3 lands on the hundreds. Observed live: 0001 -> 0301, and 16 more at the
#           same rung (captures/spice86/lord-british-tribute).
# func 42AA..42B6  len 000D B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: live:lord-british-tribute, static
# confidence: high
# notes: the four rungs (this one, asm/42B7, asm/42C1, asm/42CB) are a descending-threshold table
#           written as a chain of `cmp`/`jb` pairs, each preloading bl with its own value. The
#           ladder is inverse to need: the lower the HP, the larger the raise.
# label: sub_42aa / L_0044aa kept as they are — labels are body (AGENTS.md § 3).
sub_42aa:
L_0044aa:
        mov    0x51,%al
L_0044ad:
        mov    $0x0,%bh
L_0044af:
        mov    $0x3,%bl
L_0044b1:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044b3:
        cmp    $0x50,%al
L_0044b5:
        jb L_0044d1
