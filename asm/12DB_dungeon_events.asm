# dungeon_events — random dungeon events (gremlins, blown torches)
# name-evidence: strings 'YOUR TORCH IS BLOWN OUT!' / 'A GREMLIN STOLE SOME FOOD!'
# func 12DB..143B  len 0161 B  evidence: call+reko
# strings: "YOUR TORCH IS BLOWN OUT!"; "A GREMLIN STOLE SOME FOOD!"; "YOU FEEL A STRONG MAGIC!"
# calls: L_000e62, L_001378, L_0015ab, L_0015da, L_001610, L_004d26, L_0051df (str_out), L_005417 (+3 more)
# provenance: live:airport32 (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
dungeon_events:
L_0014db:
        mov    %al,0x20
L_0014de:
        stc
L_0014df:
        mov    0x55,%al
L_0014e2:
        cmc
L_0014e3:
        sbb    0x20,%al
L_0014e7:
        das
L_0014e8:
        cmc
L_0014e9:
        mov    %al,0x55
L_0014ec:
        mov    0x54,%al
L_0014ef:
        cmc
L_0014f0:
        sbb    $0x0,%al
L_0014f2:
        das
L_0014f3:
        cmc
L_0014f4:
        mov    %al,0x54
L_0014f7:
        mov    0x53,%al
L_0014fa:
        cmc
L_0014fb:
        sbb    $0x0,%al
L_0014fd:
        das
L_0014fe:
        cmc
L_0014ff:
        mov    %al,0x53
L_001502:
        jb L_001507
L_001504:
        jmp L_000e62
L_001507:
        ret
L_001508:
        nop
L_001509:
        call L_005417
L_00150c:
        cmp    $0x40,%al
L_00150e:
        jae L_00153e
L_001510:
        mov    $0x0,%bh
L_001512:
        mov    0x1f,%bl
L_001516:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001518:
        mov    0x25,%al
L_00151b:
        cmp    0x1b7(%di),%al
L_00151f:
        je L_001524
L_001521:
        jmp L_001378
L_001524:
        nop
L_001525:
        mov    0x197(%di),%al
L_001529:
        cmp    $0x2,%al
L_00152b:
        jne L_001530
L_00152d:
        jmp L_0015ab
L_00152f:
        nop
L_001530:
        cmp    $0x5,%al
L_001532:
        jne L_001537
L_001534:
        jmp L_0015da
L_001537:
        cmp    $0x7,%al
L_001539:
        jne L_00153e
L_00153b:
        jmp L_001610
L_00153e:
        nop
L_00153f:
        mov    $0x0,%bh
L_001541:
        mov    0x1f,%bl
L_001545:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001547:
        mov    0x25,%al
L_00154a:
        cmp    0x1b7(%di),%al
L_00154e:
        je L_001553
L_001550:
        jmp L_001378
L_001553:
        nop
L_001554:
        call L_0060ac
L_001557:
        call L_005417
L_00155a:
        js L_001564
L_00155c:
        and    $0x7,%al
L_00155e:
        cmp    0x62,%al
L_001562:
        jae L_001567
L_001564:
        jmp L_001378
L_001567:
        nop
L_001568:
        call L_004d26
L_00156b:
        call L_0060f2
L_00156e:
        call L_004d26
L_001571:
        call L_005417
L_001574:
        and    $0x77,%al
L_001576:
        mov    %al,0x20
L_001579:
        mov    0x25,%al
L_00157c:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00157e:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001580:
        and    $0x77,%al
L_001582:
        adc    0x20,%al
L_001586:
        mov    %al,0x20
L_001589:
        stc
L_00158a:
        mov    0x52,%al
L_00158d:
        cmc
L_00158e:
        sbb    0x20,%al
L_001592:
        das
L_001593:
        cmc
L_001594:
        mov    %al,0x52
L_001597:
        mov    0x51,%al
L_00159a:
        cmc
L_00159b:
        sbb    $0x0,%al
L_00159d:
        das
L_00159e:
        cmc
L_00159f:
        mov    %al,0x51
L_0015a2:
        jb L_0015a7
L_0015a4:
        jmp L_000e62
L_0015a7:
        nop
L_0015a8:
        jmp L_001378
L_0015ab:
        mov    0x26,%al
L_0015ae:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0015b0:
        je L_0015d7
L_0015b2:
        call L_0051df
        db "YOUR TORCH IS BLOWN OUT!",0x8d,0x00        # string
L_0015cf:
        call L_005e95
L_0015d2:
        mov    $0x0,%al
L_0015d4:
        mov    %al,0x26
L_0015d7:
        jmp L_001378
L_0015da:
        call L_0051df
        db "A GREMLIN STOLE SOME FOOD!",0x8d,0x00        # string
L_0015f9:
        call L_005e95
L_0015fc:
        stc
L_0015fd:
        mov    0x53,%al
L_001600:
        cmc
L_001601:
        sbb    $0x1,%al
L_001603:
        das
L_001604:
        cmc
L_001605:
        mov    %al,0x53
L_001608:
        jae L_00160d
L_00160a:
        jmp L_001378
L_00160d:
        jmp L_000e62
L_001610:
        nop
L_001611:
        call L_0051df
        db "YOU FEEL A STRONG MAGIC!",0x8d,0x00        # string
L_00162e:
        call L_005e95
L_001631:
        call L_005417
L_001634:
        and    $0x7,%al
L_001636:
        mov    %al,0x26d
L_001639:
        jmp L_001378
