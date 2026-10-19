# sub_0839 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0839..084F  len 0017 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0839:
L_000a39:
        mov    0x6a,%al
L_000a3c:
        mov    %al,0x23
L_000a3f:
        mov    0x6b,%al
L_000a42:
        mov    %al,0x24
L_000a45:
        call L_0052b3
L_000a48:
        mov    $0x50,%al
L_000a4a:
        mov    0x6,%bx
L_000a4e:
        mov    %al,(%bx,%si)
