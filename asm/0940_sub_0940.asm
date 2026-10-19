# sub_0940 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0940..094C  len 000D B  evidence: seed+reko
# strings: "PASS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0940:
L_000b40:
        mov    $0x0,%al
L_000b42:
        mov    %al,0x26
L_000b45:
        call L_0051df
        db "PASS",0x00        # string
