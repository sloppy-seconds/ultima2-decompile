# sub_06ac — mechanical clean (bulk wave); behavior not yet reviewed
# func 06AC..06AF  len 0004 B  evidence: seed+call+reko
# seams: clock_int1a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06ac:
L_0008ac:
        mov    $0x0,%ah
L_0008ae:
clock_int1a:
        int $0x1a    # clock_int1a seam
