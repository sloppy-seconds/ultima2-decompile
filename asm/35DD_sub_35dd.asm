# sub_35dd — mechanical clean (bulk wave); behavior not yet reviewed
# func 35DD..35DD  len 0001 B  evidence: seed+reko
# notes: NOP-pad seed (defects.md): single 0x90 padding byte, not a real
#        function. Disposition: clean (marked nop-pad).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35dd:
L_0037dd:
        nop
