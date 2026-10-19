# sub_47d0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47D0..47DD  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47d0:
L_0049d0:
        add    %cl,0x1f1e(%bp,%si)
L_0049d4:
        add    %cl,-0x7505(%bp,%di)
L_0049d8:
        test   %dx,-0x1800(%bp)
L_0049dc:
        xlat   %ds:(%bx)
L_0049dd:
        .byte 0x0b  # forced-kept: gas re-encodes 'or     -0x17e0(%bx,%si),%si' differently
