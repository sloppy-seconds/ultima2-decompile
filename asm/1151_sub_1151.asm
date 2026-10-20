# sub_1151 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1151..12DA  len 018A B  evidence: seed+reko
# strings: "IT'S DARK!"; "TORCH BURNED OUT!"
# calls: L_000a6f, L_001378, L_001491, L_0014cd, L_0014db, L_001508, L_00163c, L_00164c (+7 more)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1151:
L_001351:
        mov    $0x0,%bh
L_001353:
        mov    0x20,%bl
L_001357:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001359:
        mov    %al,0x1d7(%di)
L_00135d:
        ret
L_00135e:
        nop
L_00135f:
        nop
L_001360:
        call L_00167f
L_001363:
        nop
L_001364:
        mov    $0x0,%bh
L_001366:
        mov    $0x1f,%bl
L_001368:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00136a:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_00136c:
        mov    %bl,0x1f
L_001370:
        mov    0x197(%di),%al
L_001374:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001376:
        jne L_00138b
L_001378:
        decb   0x1f
L_00137c:
        mov    $0x0,%bh
L_00137e:
        mov    0x1f,%bl
L_001382:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001384:
        .byte 0x0b,0xff  # forced-kept: gas re-encodes 'or     %di,%di' differently
L_001386:
        jne L_001370
L_001388:
        jmp L_001491
L_00138b:
        nop
L_00138c:
        mov    $0x0,%bh
L_00138e:
        mov    0x1f,%bl
L_001392:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001394:
        call L_00172e
L_001397:
        mov    0x177(%di),%al
L_00139b:
        cmp    $0xf,%al
L_00139d:
        jae L_0013b5
L_00139f:
        stc
L_0013a0:
        mov    $0x0,%al
L_0013a2:
        cmc
L_0013a3:
        sbb    0x19,%al
L_0013a7:
        mov    %al,0x19
L_0013aa:
        stc
L_0013ab:
        mov    $0x0,%al
L_0013ad:
        cmc
L_0013ae:
        sbb    0x1a,%al
L_0013b2:
        mov    %al,0x1a
L_0013b5:
        nop
L_0013b6:
        mov    0x19,%al
L_0013b9:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0013bb:
        je L_0013ef
L_0013bd:
        clc
L_0013be:
        adc    0x137(%di),%al
L_0013c2:
        mov    %al,0x23
L_0013c5:
        mov    0x157(%di),%al
L_0013c9:
        mov    %al,0x24
L_0013cc:
        mov    0x23,%al
L_0013cf:
        cmp    0x0,%al
L_0013d3:
        jne L_0013e1
L_0013d5:
        mov    0x24,%al
L_0013d8:
        cmp    0x1,%al
L_0013dc:
        jne L_0013e1
L_0013de:
        jmp L_001508
L_0013e1:
        nop
L_0013e2:
        call L_00163c
L_0013e5:
        je L_00142c
L_0013e7:
        cmp    $0xff,%al
L_0013e9:
        je L_0013ef
L_0013eb:
        and    $0x7f,%al
L_0013ed:
        jne L_00142c
L_0013ef:
        nop
L_0013f0:
        mov    0x1a,%al
L_0013f3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0013f5:
        je L_001429
L_0013f7:
        clc
L_0013f8:
        adc    0x157(%di),%al
L_0013fc:
        mov    %al,0x24
L_0013ff:
        mov    0x137(%di),%al
L_001403:
        mov    %al,0x23
L_001406:
        mov    0x23,%al
L_001409:
        cmp    0x0,%al
L_00140d:
        jne L_00141b
L_00140f:
        mov    0x24,%al
L_001412:
        cmp    0x1,%al
L_001416:
        jne L_00141b
L_001418:
        jmp L_001508
L_00141b:
        nop
L_00141c:
        call L_00163c
L_00141f:
        je L_00142c
L_001421:
        cmp    $0xff,%al
L_001423:
        je L_001429
L_001425:
        and    $0x7f,%al
L_001427:
        jne L_00142c
L_001429:
        jmp L_001378
L_00142c:
        nop
L_00142d:
        call L_00164c
L_001430:
        and    $0x7,%al
L_001432:
        je L_001437
L_001434:
        jmp L_001378
L_001437:
        nop
L_001438:
        mov    0x23,%al
L_00143b:
        mov    %al,0x1f7(%di)
L_00143f:
        mov    0x24,%al
L_001442:
        mov    %al,0x217(%di)
L_001446:
        mov    0x137(%di),%al
L_00144a:
        mov    %al,0x23
L_00144d:
        mov    0x157(%di),%al
L_001451:
        mov    %al,0x24
L_001454:
        call L_00164c
L_001457:
        mov    0x8,%bx
L_00145b:
        mov    (%bx,%si),%al
L_00145d:
        and    $0xf0,%al
L_00145f:
        mov    0x8,%bx
L_001463:
        mov    %al,(%bx,%si)
L_001465:
        mov    0x1f7(%di),%al
L_001469:
        mov    %al,0x23
L_00146c:
        mov    %al,0x137(%di)
L_001470:
        mov    0x217(%di),%al
L_001474:
        mov    %al,0x24
L_001477:
        mov    %al,0x157(%di)
L_00147b:
        call L_00164c
L_00147e:
        mov    0x8,%bx
L_001482:
        mov    (%bx,%si),%al
L_001484:
        or     0x197(%di),%al
L_001488:
        mov    0x8,%bx
L_00148c:
        mov    %al,(%bx,%si)
L_00148e:
        jmp L_001378
L_001491:
        nop
L_001492:
        mov    0x26,%al
L_001495:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001497:
        jne L_0014ae
L_001499:
        call L_004d4e
L_00149c:
        call L_0051df
        db "IT'S DARK!",0x8d,0x00        # string
L_0014ab:
        jmp L_0014cd
L_0014ad:
        nop
L_0014ae:
        decb   0x26
L_0014b2:
        jne L_0014cd
L_0014b4:
        call L_0051df
        db "TORCH BURNED OUT!",0x8d,0x00        # string
L_0014ca:
        call L_005e95
L_0014cd:
        call L_006200
L_0014d0:
        mov    $0x10,%al
L_0014d2:
        call L_0014db
L_0014d5:
        call L_0052f9
L_0014d8:
        jmp L_000a6f
