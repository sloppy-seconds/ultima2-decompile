# sub_10fc — mechanical clean (bulk wave); behavior not yet reviewed
# func 10FC..110D  len 0012 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_10fc:
L_0012fc:
        clc
L_0012fd:
        mov    0x157(%di),%al
L_001301:
        adc    0x1a,%al
L_001305:
        and    $0x3f,%al
L_001307:
        mov    %al,0x24
L_00130a:
        cmp    $0x4,%al
L_00130c:
        jae L_001311
