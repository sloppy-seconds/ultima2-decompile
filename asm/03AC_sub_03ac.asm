# sub_03ac — mechanical clean (bulk wave); behavior not yet reviewed
# func 03AC..0687  len 02DC B  evidence: seed+reko
# strings: "        BATTLE STRANGE CREATURES"; "      ACROSS THE FACE OF THE EARTH"; "   SEARCH FOR CLUES IN CARELESS WORDS"; "      SPOKEN AT THE LOCAL PUB" (+8 more)
# calls: L_00033e, L_000719, L_00088f, L_000964, L_004c3e, L_004d4e, L_0051df (str_out), L_0054ca (+1 more)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_03ac:
L_0005ac:
        call L_000964
L_0005af:
        nop
L_0005b0:
        call L_004c3e
L_0005b3:
        mov    $0x1,%al
L_0005b5:
        mov    %al,0x239
L_0005b8:
        mov    $0x27,%ah
L_0005ba:
        mov    $0x4000,%cx
L_0005bd:
        mov    $0x0,%dx
L_0005c0:
        call L_0054ca
L_0005c3:
        push   %ax
L_0005c4:
        dec    %cx
L_0005c5:
        inc    %bx
L_0005c6:
        dec    %di
L_0005c7:
        push   %bp
L_0005c8:
        push   %sp
L_0005c9:
        and    %ah,(%bx,%si)
L_0005cb:
        movb   $0x17,0x2f
L_0005d0:
        movb   $0x0,0x2e
L_0005d5:
        call L_0051df
        db "        BATTLE STRANGE CREATURES",0x00        # string
L_0005f9:
        movb   $0x0,0x2e
L_0005fe:
        movb   $0x18,0x2f
L_000603:
        call L_0051df
        db "      ACROSS THE FACE OF THE EARTH",0x00        # string
L_000629:
        call L_00088f
L_00062c:
        call L_00558f
L_00062f:
        call L_004d4e
L_000632:
        mov    $0x27,%ah
L_000634:
        mov    $0x4000,%cx
L_000637:
        mov    $0x0,%dx
L_00063a:
        call L_0054ca
L_00063d:
        push   %ax
L_00063e:
        dec    %cx
L_00063f:
        inc    %bx
L_000640:
        push   %sp
L_000641:
        push   %di
L_000642:
        dec    %si
L_000643:
        and    %ah,(%bx,%si)
L_000645:
        movb   $0x0,0x2e
L_00064a:
        movb   $0x17,0x2f
L_00064f:
        call L_0051df
        db "   SEARCH FOR CLUES IN CARELESS WORDS",0x00        # string
L_000678:
        .byte 0xc6,0x06,0x2e,0x00,0x02  # forced-kept: gas re-encodes 'movb   $0x2,0x2e' differently
L_00067d:
        movb   $0x18,0x2f
L_000682:
        call L_0051df
        db "      SPOKEN AT THE LOCAL PUB",0x00        # string
L_0006a3:
        call L_00088f
L_0006a6:
        jmp L_000719
L_0006a8:
        nop
L_0006a9:
        call L_00558f
L_0006ac:
        call L_004d4e
L_0006af:
        mov    $0x27,%ah
L_0006b1:
        mov    $0x4000,%cx
L_0006b4:
        mov    $0x0,%dx
L_0006b7:
        call L_0054ca
L_0006ba:
        push   %ax
L_0006bb:
        dec    %cx
L_0006bc:
        inc    %bx
L_0006bd:
        inc    %bx
L_0006be:
        inc    %cx
L_0006bf:
        push   %bx
L_0006c0:
        and    %ah,(%bx,%si)
L_0006c2:
        movb   $0x0,0x2e
L_0006c7:
        movb   $0x17,0x2f
L_0006cc:
        call L_0051df
        db "        PLEAD WITH MEDIEVAL KINGS",0x00        # string
L_0006f1:
        .byte 0xc6,0x06,0x2e,0x00,0x04  # forced-kept: gas re-encodes 'movb   $0x4,0x2e' differently
L_0006f6:
        movb   $0x18,0x2f
L_0006fb:
        call L_0051df
        db "         FOR ASSISTANCE",0x00        # string
L_000716:
        call L_00088f
L_000719:
        call L_00558f
L_00071c:
        call L_004d4e
L_00071f:
        mov    $0x27,%ah
L_000721:
        mov    $0x4000,%cx
L_000724:
        mov    $0x0,%dx
L_000727:
        call L_0054ca
L_00072a:
        push   %ax
L_00072b:
        dec    %cx
L_00072c:
        inc    %bx
L_00072d:
        inc    %sp
L_00072e:
        dec    %si
L_00072f:
        inc    %di
L_000730:
        and    %ah,(%bx,%si)
L_000732:
        movb   $0x0,0x2e
L_000737:
        movb   $0x17,0x2f
L_00073c:
        call L_0051df
        db "   TRAVERSE DEEP DARK DEADLY DUNGEONS",0x00        # string
L_000765:
        .byte 0xc6,0x06,0x2e,0x00,0x01  # forced-kept: gas re-encodes 'movb   $0x1,0x2e' differently
L_00076a:
        movb   $0x18,0x2f
L_00076f:
        call L_0051df
        db "      AND TALL TERRIFYING TOWERS",0x00        # string
L_000793:
        call L_00088f
L_000796:
        call L_00558f
L_000799:
        call L_004d4e
L_00079c:
        mov    $0x27,%ah
L_00079e:
        mov    $0x4000,%cx
L_0007a1:
        mov    $0x0,%dx
L_0007a4:
        call L_0054ca
L_0007a7:
        push   %ax
L_0007a8:
        dec    %cx
L_0007a9:
        inc    %bx
L_0007aa:
        push   %bx
L_0007ab:
        push   %ax
L_0007ac:
        inc    %cx
L_0007ad:
        and    %ah,(%bx,%si)
L_0007af:
        movb   $0x0,0x2e
L_0007b4:
        movb   $0x17,0x2f
L_0007b9:
        call L_0051df
        db "      TRAVEL THROUGHOUT THE GALAXY",0x00        # string
L_0007df:
        .byte 0xc6,0x06,0x2e,0x00,0x01  # forced-kept: gas re-encodes 'movb   $0x1,0x2e' differently
L_0007e4:
        movb   $0x18,0x2f
L_0007e9:
        call L_0051df
        db "  TO THE PLANETS OF OUR SOLAR SYSTEM",0x00        # string
L_000811:
        call L_00088f
L_000814:
        call L_00558f
L_000817:
        call L_004d4e
L_00081a:
        mov    $0x27,%ah
L_00081c:
        mov    $0x4000,%cx
L_00081f:
        mov    $0x0,%dx
L_000822:
        call L_0054ca
L_000825:
        push   %ax
L_000826:
        dec    %cx
L_000827:
        inc    %bx
L_000828:
        dec    %bp
L_000829:
        dec    %cx
L_00082a:
        dec    %si
L_00082b:
        and    %ah,(%bx,%si)
L_00082d:
        movb   $0x0,0x2e
L_000832:
        movb   $0x17,0x2f
L_000837:
        call L_0051df
        db "   AND CONQUER TIME ITSELF TO BATTLE",0x00        # string
L_00085f:
        .byte 0xc6,0x06,0x2e,0x00,0x08  # forced-kept: gas re-encodes 'movb   $0x8,0x2e' differently
L_000864:
        movb   $0x18,0x2f
L_000869:
        call L_0051df
        db "MINAX THE ENCHANTRESS",0x00        # string
L_000882:
        call L_00088f
L_000885:
        jmp L_00033e
