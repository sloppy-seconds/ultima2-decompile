# sub_0afc — mechanical clean (bulk wave); behavior not yet reviewed
# func 0AFC..0B06  len 000B B  evidence: seed+reko
# calls: L_005111
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0afc:
L_000cfc:
        mov    $0x0,%bh
L_000cfe:
        mov    0x29,%bl
L_000d02:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000d04:
        call L_005111
