# sub_530f — mechanical clean (bulk wave); behavior not yet reviewed
# func 530F..5316  len 0008 B  evidence: reko
# seams: dos_int21
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_530f:
L_00550f:
        mov    $0xf,%ah
L_005511:
        lea    0x245,%dx
L_005515:
dos_int21:
        int $0x21    # dos_int21 seam
