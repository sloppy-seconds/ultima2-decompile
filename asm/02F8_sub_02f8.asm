# sub_02f8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02F8..031D  len 0026 B  evidence: reko
# strings: "'D' - FOR A DEMONSTRATION"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02f8:
L_0004f8:
        push   %es
L_0004f9:
        das
L_0004fa:
        add    %cl,(%di)
L_0004fc:
        mov    $0x6,%al
L_0004fe:
        mov    %al,0x2e
L_000501:
        call L_0051df
        db "'D' - FOR A DEMONSTRATION",0x00        # string
