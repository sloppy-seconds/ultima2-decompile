# sub_6304 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6304..6376  len 0073 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6304:
L_006504:
        mov    $0x0,%bh
L_006506:
        mov    0x482,%bl
L_00650a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00650c:
        mov    %cs:0x6217(%di),%al
L_006511:
        mov    %al,0x479
L_006514:
        mov    %al,0x47b
L_006517:
        mov    %cs:0x6221(%di),%al
L_00651c:
        mov    %al,0x47a
L_00651f:
        mov    %cs:0x6229(%di),%al
L_006524:
        mov    %al,0x47c
L_006527:
        call L_0069b3
L_00652a:
        mov    $0x0,%bh
L_00652c:
        mov    0x482,%bl
L_006530:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006532:
        mov    %cs:0x6222(%di),%al
L_006537:
        mov    %al,0x47a
L_00653a:
        mov    %al,0x47c
L_00653d:
        mov    %cs:0x6218(%di),%al
L_006542:
        mov    %al,0x47b
L_006545:
        call L_0069b3
L_006548:
        mov    $0x0,%bh
L_00654a:
        mov    0x482,%bl
L_00654e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006550:
        mov    %cs:0x622a(%di),%al
L_006555:
        mov    %al,0x47c
L_006558:
        call L_0069b3
L_00655b:
        mov    $0x0,%bh
L_00655d:
        mov    0x482,%bl
L_006561:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006563:
        mov    %cs:0x6217(%di),%al
L_006568:
        mov    %al,0x47b
L_00656b:
        call L_0069b3
L_00656e:
        mov    $0x0,%bh
L_006570:
        mov    0x482,%bl
L_006574:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006576:
        ret
