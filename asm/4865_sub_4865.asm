# sub_4865 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4865..486B  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4865:
L_004a65:
        test   %dx,%si
L_004a67:
        add    %cl,(%bp,%si)
L_004a69:
        .byte 0xc0,0x74,0x33  # forced-kept: gas re-encodes 'shlb   $0x8b,0x33(%si)' differently
