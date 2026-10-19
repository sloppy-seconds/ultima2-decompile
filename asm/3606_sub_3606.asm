# sub_3606 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3606..360D  len 0008 B  evidence: seed+reko
# calls: L_00543e
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3606:
L_003806:
        or     $0x20,%al
L_003808:
        mov    %al,0x1f
L_00380b:
        call L_00543e
