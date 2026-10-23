# sub_0cdc — overworld spawner: store mon_y[DS:1F] and mirror it to staging DS:24
# Reached from asm/0CD4_sub_0cd4.asm, which does `and al,0x3f` first — the overworld is
# a torus and that is where the wrap is enforced on the way in. asm/0CD2_sub_0cd2.asm
# sends a negative value out through the common exit at 0DAF instead.
# Same caveat as asm/0CC0_sub_0cc0.asm: placement store, not movement, and the target
# slot is DS:1F, so data breakpoints on a fixed slot offset will miss it.
# provenance: static, reassembled in address order 2026-10-23
# confidence: high
# func 0CDC..0CED  len 0012 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cdc:
L_000edc:
        mov    $0x0,%bh
L_000ede:
        mov    0x1f,%bl
L_000ee2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ee4:
        mov    %al,0x157(%di)
L_000ee8:
        mov    %al,0x24
L_000eeb:
        call L_0052b3
