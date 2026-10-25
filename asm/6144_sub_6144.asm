# sub_6144 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6144..6290  len 014D B  evidence: call+reko
# body corrected: 2026-10-28e -- evidence: every line of this span was rendered as a `db` byte
#           with the marker `split: branch target inside data`, because the clean wave bailed on
#           the whole run. It is code: the labels in this file are the branch targets, and each
#           run between two of them assembles back to its own bytes as a real instruction. Each
#           mnemonic below was decoded from the bytes and then re-assembled by gas at its own
#           address and compared -- where gas produced different bytes the line stayed a
#           `.byte` forced-keep, which is 5 of 160 lines. Found by the raw-byte span scan in
#           disasm/defects.md.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6144:
L_006344:
        call L_004d4e
L_006347:
        mov    $0x0,%al
L_006349:
        mov    %al,0x482
L_00634c:
        call L_006625
L_00634f:
        mov    $0x0,%bh
L_006351:
        mov    0x482,%bl
L_006355:
        .byte 0x8b, 0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006357:
        mov    0x497(%di),%al
L_00635b:
        .byte 0x0a, 0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00635d:
        jns L_006392
L_00635f:
        call L_006625
L_006362:
        mov    0x497(%di),%al
L_006366:
        and    $0x40,%al
L_006368:
        jne L_00636d
L_00636a:
        jmp L_00640c
L_00636d:
        mov    0x497(%di),%al
L_006371:
        and    $0x20,%al
L_006373:
        je L_006378
L_006375:
        jmp L_00640c
L_006378:
        call L_00668d
L_00637b:
        mov    0x482,%al
L_00637e:
        .byte 0x0a, 0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_006380:
        je L_006385
L_006382:
        jmp L_00640c
L_006385:
        incb   0x482
L_006389:
        mov    0x482,%al
L_00638c:
        cmp    $0x8,%al
L_00638e:
        jae L_00640c
L_006390:
        jmp L_00634f
L_006392:
        mov    0x497(%di),%al
L_006396:
        and    $0x20,%al
L_006398:
        je L_00639d
L_00639a:
        call L_006794
L_00639d:
        mov    0x497(%di),%al
L_0063a1:
        and    $0x10,%al
L_0063a3:
        je L_0063ab
L_0063a5:
        call L_00680c
L_0063a8:
        jmp L_0063b6
L_0063aa:
        nop
L_0063ab:
        mov    0x497(%di),%al
L_0063af:
        and    $0x40,%al
L_0063b1:
        je L_0063b6
L_0063b3:
        call L_0068cb
L_0063b6:
        mov    0x48f(%di),%al
L_0063ba:
        .byte 0x0a, 0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0063bc:
        jns L_0063d7
L_0063be:
        call L_006577
L_0063c1:
        mov    0x48f(%di),%al
L_0063c5:
        and    $0x40,%al
L_0063c7:
        je L_0063da
L_0063c9:
        mov    0x48f(%di),%al
L_0063cd:
        and    $0x20,%al
L_0063cf:
        jne L_0063da
L_0063d1:
        call L_0066e2
L_0063d4:
        jmp L_0063da
L_0063d6:
        nop
L_0063d7:
        call L_006491
L_0063da:
        mov    0x49f(%di),%al
L_0063de:
        .byte 0x0a, 0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0063e0:
        jns L_0063fb
L_0063e2:
        call L_0065ce
L_0063e5:
        mov    0x49f(%di),%al
L_0063e9:
        and    $0x40,%al
L_0063eb:
        je L_0063fe
L_0063ed:
        mov    0x49f(%di),%al
L_0063f1:
        and    $0x20,%al
L_0063f3:
        jne L_0063fe
L_0063f5:
        call L_00673f
L_0063f8:
        jmp L_0063fe
L_0063fa:
        nop
L_0063fb:
        call L_006504
L_0063fe:
        incb   0x482
L_006402:
        mov    0x482,%al
L_006405:
        cmp    $0x7,%al
L_006407:
        jae L_00640c
L_006409:
        jmp L_00634f
L_00640c:
        ret
L_00640d:
        add    %al,0x60(%bx,%si)
L_006410:
        jo L_00648a
L_006412:
        jl L_006492
L_006414:
        jg L_006495
L_006416:
        .byte 0x7f
L_006417:
        .byte 0xff
L_006418:
        mov    $0x8f9f,%di
L_00641b:
        xchg   %ax,-0x7f7f(%bp,%di)
L_00641f:
        addb   $0x30,0x2000(%bx,%si)
L_006424:
        cmp    %bh,(%si)
L_006426:
        ds aas
L_006428:
        aas
L_006429:
        jg L_00648a
L_00642b:
        dec    %di
L_00642c:
        inc    %di
L_00642d:
        inc    %bx
L_00642e:
        inc    %cx
L_00642f:
        inc    %ax
L_006430:
        inc    %ax
L_006431:
        adc    %cl,0x64(%bx,%si)
L_006434:
        jb L_0064af
L_006436:
        jl L_0064b7
L_006438:
        jg L_00646a
L_00643a:
        pop    %ax
L_00643b:
        insb   (%dx),%es:(%di)
L_00643c:
        jbe L_0064b9
L_00643e:
        jl L_0064bf
L_006440:
        jg L_006431
L_006442:
        mov    $0x9b,%bh
L_006444:
        lea    -0x7f7d(%bp),%ax
L_006448:
        or     $0xa7,%bh
L_00644b:
        xchg   %ax,%bx
L_00644c:
        mov    %ax,-0x7f7d(%si)
L_006450:
        xorb   $0x4d,0x5b(%bx)
L_006454:
        inc    %si
L_006455:
        inc    %dx
L_006456:
        inc    %ax
L_006457:
        inc    %ax
L_006458:
        inc    %ax
L_006459:
        addr32 push %bx
L_00645b:
        dec    %cx
L_00645c:
        inc    %sp
L_00645d:
        inc    %dx
L_00645e:
        inc    %ax
L_00645f:
        inc    %ax
L_006460:
        inc    %ax
L_006461:
        sub    (%di),%dh
L_006463:
        cmp    (%di),%di
L_006465:
        ds aas
L_006467:
        aas
L_006468:
        aas
L_006469:
        .byte 0x8
L_00646a:
        .byte 0x24
L_00646b:
        xor    (%bx,%di),%bh
L_00646d:
        cmp    $0x3e,%al
L_00646f:
        aas
L_006470:
        aas
L_006471:
        sbb    %ch,(%si)
L_006473:
        cmp    %ss:(%di),%bh
L_006476:
        ds aas
L_006478:
        aas
L_006479:
        ja L_0064d6
L_00647b:
        dec    %bp
L_00647c:
        inc    %si
L_00647d:
        inc    %bx
L_00647e:
        inc    %cx
L_00647f:
        inc    %ax
L_006480:
        inc    %ax
L_006481:
        addr32 push %bx
L_006483:
        dec    %cx
L_006484:
        inc    %bp
L_006485:
        inc    %dx
L_006486:
        inc    %cx
L_006487:
        inc    %ax
L_006488:
        inc    %ax
L_006489:
        outsw  %ds:(%si),(%dx)
L_00648a:
        push   %di
L_00648b:
        dec    %bx
L_00648c:
        inc    %bp
L_00648d:
        inc    %dx
L_00648e:
        inc    %ax
L_00648f:
        inc    %ax
L_006490:
        inc    %ax
