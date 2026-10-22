# cast_spell_flow — CAST command spell selection + checks
# name-evidence: strings 'NEED WAND OR STAFF!' / 'NO SPELL!'; cmd_C jumps into this range
# func 3139..330B  len 01D3 B  evidence: call+reko
# strings: "-FAILED!"; "-FAILED!"
# calls: L_000c33, L_001651, L_0030d1, L_003432, L_0034a2, L_0034a5, L_0034ad, L_0034d2 (+9 more)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cast_spell_flow:
L_003339:
        nop
L_00333a:
        push   %bx
L_00333b:
        push   %es
L_00333c:
        mov    %ax,%es
L_00333e:
        mov    $0x0,%ax
L_003341:
        mov    $0x1900,%bx
L_003344:
        mov    %ax,%es:(%bx)
L_003347:
        add    $0x2,%bx
L_00334a:
        cmp    $0x1f40,%bx
L_00334e:
        jne L_003344
L_003350:
        pop    %es
L_003351:
        pop    %bx
L_003352:
        ret
L_003353:
        nop
L_003354:
        mov    0x63,%al
L_003357:
        clc
L_003358:
        adc    $0x24,%al
L_00335a:
        call L_00528c
L_00335d:
        mov    0xd7,%al
L_003360:
        clc
L_003361:
        adc    0xd8,%al
L_003365:
        jne L_003385
L_003367:
        call L_0051df
        db 0x8d,"NEED WAND OR STAFF!",0x00        # string
L_00337f:
        call L_006083
L_003382:
        jmp L_000c33
L_003385:
        nop
L_003386:
        mov    0x63,%al
L_003389:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00338b:
        jne L_003390
L_00338d:
        jmp L_000c33
L_003390:
        mov    $0x0,%ah
L_003392:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_003394:
        mov    0xb6(%di),%al
L_003398:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00339a:
        jne L_0033b0
L_00339c:
        call L_0051df
        db 0x8d,"NO SPELL!",0x00        # string
L_0033aa:
        call L_006083
L_0033ad:
        jmp L_000c33
L_0033b0:
        call L_0061c3
L_0033b3:
        mov    $0x0,%bh
L_0033b5:
        mov    0x63,%bl
L_0033b9:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0033bb:
        stc
L_0033bc:
        mov    0xb6(%di),%al
L_0033c0:
        cmc
L_0033c1:
        sbb    $0x1,%al
L_0033c3:
        das
L_0033c4:
        cmc
L_0033c5:
        mov    %al,0xb6(%di)
L_0033c9:
        mov    0x4a,%al
L_0033cc:
        cmp    $0x4,%al
L_0033ce:
        jae L_0033e2
L_0033d0:
        call L_0051df
        db "-FAILED!",0x00        # string
L_0033dc:
        call L_006083
L_0033df:
        jmp L_000c33
L_0033e2:
        nop
L_0033e3:
        mov    0x63,%al
L_0033e6:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0033e8:
        jne L_0033ed
L_0033ea:
        jmp L_000c33
L_0033ed:
        cmp    $0x1,%al
L_0033ef:
        je L_00341c
L_0033f1:
        cmp    $0x2,%al
L_0033f3:
        je L_003424
L_0033f5:
        cmp    $0x3,%al
L_0033f7:
        je L_003453
L_0033f9:
        cmp    $0x4,%al
L_0033fb:
        je L_003472
L_0033fd:
        cmp    $0x5,%al
L_0033ff:
        je L_003410
L_003401:
        cmp    $0x6,%al
L_003403:
        je L_003413
L_003405:
        cmp    $0x7,%al
L_003407:
        je L_003416
L_003409:
        cmp    $0x8,%al
L_00340b:
        jne L_003419
L_00340d:
        jmp L_0034d2
L_003410:
        jmp L_0034a2
L_003413:
        jmp L_0034a5
L_003416:
        jmp L_0034ad
L_003419:
        jmp L_003501
L_00341c:
        mov    $0x96,%al
L_00341e:
        mov    %al,0x26
L_003421:
        jmp L_000c33
L_003424:
        mov    0x4a,%al
L_003427:
        cmp    $0x4,%al
L_003429:
        je L_00345a
L_00342b:
        mov    0x25,%al
L_00342e:
        cmp    $0xf,%al
L_003430:
        jb L_003444
L_003432:
        call L_0051df
        db "-FAILED!",0x00        # string
L_00343e:
        call L_006083
L_003441:
        jmp L_000c33
L_003444:
        clc
L_003445:
        adc    $0x1,%al
L_003447:
        call L_001651
L_00344a:
        jne L_003432
L_00344c:
        incb   0x25
L_003450:
        jmp L_003a2a
L_003453:
        mov    0x4a,%al
L_003456:
        cmp    $0x4,%al
L_003458:
        je L_00342b
L_00345a:
        mov    0x25,%al
L_00345d:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00345f:
        je L_0034a2
L_003461:
        stc
L_003462:
        cmc
L_003463:
        sbb    $0x1,%al
L_003465:
        cmc
L_003466:
        call L_001651
L_003469:
        jne L_003432
L_00346b:
        decb   0x25
L_00346f:
        jmp L_003a2a
L_003472:
        clc
L_003473:
        mov    0x0,%al
L_003476:
        adc    0x2,%al
L_00347a:
        and    $0xf,%al
L_00347c:
        je L_003432
L_00347e:
        mov    %al,0x23
L_003481:
        mov    0x1,%al
L_003484:
        adc    0x3,%al
L_003488:
        and    $0xf,%al
L_00348a:
        je L_003432
L_00348c:
        mov    %al,0x24
L_00348f:
        mov    0x25,%al
L_003492:
        call L_001651
L_003495:
        jns L_003432
L_003497:
        mov    $0x0,%al
L_003499:
        mov    0x8,%bx
L_00349d:
        mov    %al,(%bx,%si)
L_00349f:
        jmp L_000c33
L_0034a2:
        jmp L_003a44
L_0034a5:
        call L_005417
L_0034a8:
        js L_003432
L_0034aa:
        jmp L_003501
L_0034ac:
        nop
L_0034ad:
        call L_00350c
L_0034b0:
        je L_003432
L_0034b2:
        mov    0x56,%al
L_0034b5:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0034b7:
        adc    $0x1e,%al
L_0034b9:
        mov    %al,0x20
L_0034bc:
        mov    0x177(%di),%al
L_0034c0:
        cmc
L_0034c1:
        sbb    0x20,%al
L_0034c5:
        cmc
L_0034c6:
        mov    %al,0x177(%di)
L_0034ca:
        jb L_0034cf
L_0034cc:
        jmp L_0030d1
L_0034cf:
        jmp L_000c33
L_0034d2:
        call L_005417
L_0034d5:
        and    $0xf,%al
L_0034d7:
        or     $0x1,%al
L_0034d9:
        mov    %al,0x23
L_0034dc:
        call L_005417
L_0034df:
        and    $0xf,%al
L_0034e1:
        or     $0x1,%al
L_0034e3:
        mov    %al,0x24
L_0034e6:
        mov    0x25,%al
L_0034e9:
        call L_001651
L_0034ec:
        je L_0034f1
L_0034ee:
        jmp L_003432
L_0034f1:
        nop
L_0034f2:
        mov    0x23,%al
L_0034f5:
        mov    %al,0x0
L_0034f8:
        mov    0x24,%al
L_0034fb:
        mov    %al,0x1
L_0034fe:
        jmp L_000c33
L_003501:
        call L_00350c
L_003504:
        jne L_003509
L_003506:
        jmp L_003432
L_003509:
        jmp L_0030d1
