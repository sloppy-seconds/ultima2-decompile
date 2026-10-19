# sub_5d14 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5D14..5D21  len 000E B  evidence: seed+reko
# calls: L_005eb2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5d14:
L_005f14:
        shl    $1,%bx
L_005f16:
        mov    %cs:0x5d9b(%bx),%bp
L_005f1b:
        mov    %cs:0x1(%bp),%bx
L_005f1f:
        call L_005eb2
