# tavern_menu — tavern buy/drink menu
# name-evidence: strings 'WELCOME TO THE PUB!' / 'HERE, HAVE A STRONG ONE!'
# func 15E1..1798  len 01B8 B  evidence: seed+reko
# strings: "WELCOME TO THE PUB!"; "HERE, HAVE A STRONG ONE!"; "TIP HOW MUCH? "; "THE BARKEEP SAYS:"
# calls: L_000c33, L_00175d, L_001886, L_001baf, L_002228, L_002252, L_0051df (str_out), L_0052d8 (+1 more)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
tavern_menu:
L_0017e1:
        jmp L_001baf
L_0017e4:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0017e5:
        call L_0051df
        db "WELCOME TO THE PUB!",0x0d,"1-BUY, 2-TIP --- ",0x00        # string
L_00180e:
        call L_002228
L_001811:
        .byte 0x3c,0x01  # forced-kept: gas re-encodes 'cmp    $0x1,%al' differently
L_001813:
        je L_00181c
L_001815:
        .byte 0x3c,0x02  # forced-kept: gas re-encodes 'cmp    $0x2,%al' differently
L_001817:
        je L_001851
L_001819:
        jmp L_000c33
L_00181c:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00181d:
        .byte 0xb0,0x05  # forced-kept: gas re-encodes 'mov    $0x5,%al' differently
L_00181f:
        .byte 0xa2,0x28,0x00  # forced-kept: gas re-encodes 'mov    %al,0x28' differently
L_001822:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_001824:
        .byte 0xa2,0x27,0x00  # forced-kept: gas re-encodes 'mov    %al,0x27' differently
L_001827:
        call L_002252
L_00182a:
        call L_0051df
        db "HERE, HAVE A STRONG ONE!",0x0d,0x00        # string
L_001847:
        call L_005417
L_00184a:
        .byte 0x24,0x03  # forced-kept: gas re-encodes 'and    $0x3,%al' differently
L_00184c:
        .byte 0xb0,0x01  # forced-kept: gas re-encodes 'mov    $0x1,%al' differently
L_00184e:
        jmp L_001886
L_001850:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001851:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001852:
        call L_0051df
        db "TIP HOW MUCH? ",0x00        # string
L_001864:
        call L_002228
L_001867:
        .byte 0xa2,0x25,0x00  # forced-kept: gas re-encodes 'mov    %al,0x25' differently
L_00186a:
        .byte 0xa2,0x28,0x00  # forced-kept: gas re-encodes 'mov    %al,0x28' differently
L_00186d:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_00186f:
        .byte 0xa2,0x27,0x00  # forced-kept: gas re-encodes 'mov    %al,0x27' differently
L_001872:
        call L_002252
L_001875:
        call L_005417
L_001878:
        call L_0052d8
L_00187b:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_00187c:
        .byte 0x12,0x06,0x25,0x00  # forced-kept: gas re-encodes 'adc    0x25,%al' differently
L_001880:
        .byte 0x3c,0x0a  # forced-kept: gas re-encodes 'cmp    $0xa,%al' differently
L_001882:
        jb L_001886
L_001884:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_001886:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001887:
        .byte 0xa2,0x25,0x00  # forced-kept: gas re-encodes 'mov    %al,0x25' differently
L_00188a:
        call L_0051df
        db "THE BARKEEP SAYS:",0x0d,0x00        # string
L_0018a0:
        .byte 0xa0,0x25,0x00  # forced-kept: gas re-encodes 'mov    0x25,%al' differently
L_0018a3:
        .byte 0xb4,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%ah' differently
L_0018a5:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_0018a7:
        .byte 0x46  # forced-kept: gas re-encodes 'inc    %si' differently
L_0018a8:
        .byte 0x2e,0x8d,0x06,0xbc,0x16  # forced-kept: gas re-encodes 'lea    %cs:0x16bc,%ax' differently
L_0018ad:
        .byte 0xa3,0x27,0x00  # forced-kept: gas re-encodes 'mov    %ax,0x27' differently
L_0018b0:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_0018b2:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_0018b4:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0018b6:
        call L_00175d
L_0018b9:
        jmp L_000c33
L_0018bc:
        .byte 0x00,0x43,0x41  # forced-kept: gas re-encodes 'add    %al,0x41(%bp,%di)' differently
L_0018bf:
        .byte 0x55  # forced-kept: gas re-encodes 'push   %bp' differently
L_0018c0:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_0018c1:
        .byte 0x48  # forced-kept: gas re-encodes 'dec    %ax' differently
L_0018c2:
        .byte 0x2e,0x2e,0x2e,0x00,0x49,0x53  # forced-kept: gas re-encodes 'cs cs add %cl,%cs:0x53(%bx,%di)' differently
L_0018c8:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_0018c9:
        .byte 0x27  # forced-kept: gas re-encodes 'daa' differently
L_0018ca:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_0018cb:
        .byte 0x20,0x54,0x48  # forced-kept: gas re-encodes 'and    %dl,0x48(%si)' differently
L_0018ce:
        .byte 0x49  # forced-kept: gas re-encodes 'dec    %cx' differently
L_0018cf:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_0018d0:
        .byte 0x20,0x41,0x20  # forced-kept: gas re-encodes 'and    %al,0x20(%bx,%di)' differently
L_0018d3:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_0018d4:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_0018d5:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_0018d6:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_0018d7:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_0018d8:
        .byte 0x20,0x47,0x41  # forced-kept: gas re-encodes 'and    %al,0x41(%bx)' differently
L_0018db:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_0018dc:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_0018dd:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0018de:
        .byte 0x00,0x48,0x48  # forced-kept: gas re-encodes 'add    %cl,0x48(%bx,%si)' differently
L_0018e1:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_0018e2:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_0018e3:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_0018e4:
        .byte 0x2e,0x2e,0x2e,0x00,0x53,0x4f  # forced-kept: gas re-encodes 'cs cs add %dl,%cs:0x4f(%bp,%di)' differently
L_0018ea:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_0018eb:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_0018ec:
        .byte 0x20,0x46,0x49  # forced-kept: gas re-encodes 'and    %al,0x49(%bp)' differently
L_0018ef:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_0018f0:
        .byte 0x48  # forced-kept: gas re-encodes 'dec    %ax' differently
L_0018f1:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_0018f2:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_0018f3:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_0018f4:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_0018f5:
        .byte 0x20,0x57,0x45  # forced-kept: gas re-encodes 'and    %dl,0x45(%bx)' differently
L_0018f8:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_0018f9:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_0018fa:
        .byte 0x20,0x4d,0x41  # forced-kept: gas re-encodes 'and    %cl,0x41(%di)' differently
L_0018fd:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_0018fe:
        .byte 0x49  # forced-kept: gas re-encodes 'dec    %cx' differently
L_0018ff:
        .byte 0x43  # forced-kept: gas re-encodes 'inc    %bx' differently
L_001900:
        .byte 0x20,0x48,0x45  # forced-kept: gas re-encodes 'and    %cl,0x45(%bx,%si)' differently
L_001903:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_001904:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_001905:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001906:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_001908:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_001909:
        .byte 0x56  # forced-kept: gas re-encodes 'push   %si' differently
L_00190a:
        .byte 0x49  # forced-kept: gas re-encodes 'dec    %cx' differently
L_00190b:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00190c:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_00190d:
        .byte 0x4f  # forced-kept: gas re-encodes 'dec    %di' differently
L_00190e:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_00190f:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001910:
        .byte 0x20,0x55,0x53  # forced-kept: gas re-encodes 'and    %dl,0x53(%di)' differently
L_001913:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001914:
        .byte 0x20,0x53,0x4b  # forced-kept: gas re-encodes 'and    %dl,0x4b(%bp,%di)' differently
L_001917:
        .byte 0x55  # forced-kept: gas re-encodes 'push   %bp' differently
L_001918:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_001919:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_00191a:
        .byte 0x20,0x4b,0x45  # forced-kept: gas re-encodes 'and    %cl,0x45(%bp,%di)' differently
L_00191d:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_00191e:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00191f:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_001921:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001922:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_001923:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_001924:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_001925:
        .byte 0x4f  # forced-kept: gas re-encodes 'dec    %di' differently
L_001926:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_001927:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001928:
        .byte 0x20,0x57,0x45  # forced-kept: gas re-encodes 'and    %dl,0x45(%bx)' differently
L_00192b:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00192c:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_00192d:
        .byte 0x20,0x42,0x4c  # forced-kept: gas re-encodes 'and    %al,0x4c(%bp,%si)' differently
L_001930:
        .byte 0x55  # forced-kept: gas re-encodes 'push   %bp' differently
L_001931:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001932:
        .byte 0x20,0x54,0x41  # forced-kept: gas re-encodes 'and    %dl,0x41(%si)' differently
L_001935:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001936:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001937:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_001938:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001939:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00193a:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_00193c:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_00193d:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00193e:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_00193f:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001940:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001941:
        .byte 0x20,0x43,0x41  # forced-kept: gas re-encodes 'and    %al,0x41(%bp,%di)' differently
L_001944:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_001945:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_001946:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_001947:
        .byte 0x20,0x57,0x41  # forced-kept: gas re-encodes 'and    %dl,0x41(%bx)' differently
L_00194a:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_00194b:
        .byte 0x44  # forced-kept: gas re-encodes 'inc    %sp' differently
L_00194c:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00194d:
        .byte 0x20,0x4f,0x52  # forced-kept: gas re-encodes 'and    %cl,0x52(%bx)' differently
L_001950:
        .byte 0x20,0x53,0x54  # forced-kept: gas re-encodes 'and    %dl,0x54(%bp,%di)' differently
L_001953:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_001954:
        .byte 0x46  # forced-kept: gas re-encodes 'inc    %si' differently
L_001955:
        .byte 0x46  # forced-kept: gas re-encodes 'inc    %si' differently
L_001956:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001957:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_001959:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_00195a:
        .byte 0x55  # forced-kept: gas re-encodes 'push   %bp' differently
L_00195b:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00195c:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_00195d:
        .byte 0x44  # forced-kept: gas re-encodes 'inc    %sp' differently
L_00195e:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00195f:
        .byte 0x20,0x43,0x41  # forced-kept: gas re-encodes 'and    %al,0x41(%bp,%di)' differently
L_001962:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_001963:
        .byte 0x52  # forced-kept: gas re-encodes 'push   %dx' differently
L_001964:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_001965:
        .byte 0x20,0x4b,0x45  # forced-kept: gas re-encodes 'and    %cl,0x45(%bp,%di)' differently
L_001968:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_001969:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00196a:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_00196c:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00196d:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_00196e:
        .byte 0x4b  # forced-kept: gas re-encodes 'dec    %bx' differently
L_00196f:
        .byte 0x48  # forced-kept: gas re-encodes 'dec    %ax' differently
L_001970:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001971:
        .byte 0x20,0x4f,0x50  # forced-kept: gas re-encodes 'and    %cl,0x50(%bx)' differently
L_001974:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001975:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_001976:
        .byte 0x20,0x53,0x50  # forced-kept: gas re-encodes 'and    %dl,0x50(%bp,%di)' differently
L_001979:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00197a:
        .byte 0x43  # forced-kept: gas re-encodes 'inc    %bx' differently
L_00197b:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_00197c:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
L_00197e:
        .byte 0x50  # forced-kept: gas re-encodes 'push   %ax' differently
L_00197f:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_001980:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_001981:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_001982:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001983:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001984:
        .byte 0x20,0x4e,0x45  # forced-kept: gas re-encodes 'and    %cl,0x45(%bp)' differently
L_001987:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_001988:
        .byte 0x44  # forced-kept: gas re-encodes 'inc    %sp' differently
L_001989:
        .byte 0x20,0x42,0x52  # forced-kept: gas re-encodes 'and    %al,0x52(%bp,%si)' differently
L_00198c:
        .byte 0x41  # forced-kept: gas re-encodes 'inc    %cx' differently
L_00198d:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00198e:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_00198f:
        .byte 0x20,0x42,0x55  # forced-kept: gas re-encodes 'and    %al,0x55(%bp,%si)' differently
L_001992:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_001993:
        .byte 0x54  # forced-kept: gas re-encodes 'push   %sp' differently
L_001994:
        .byte 0x4f  # forced-kept: gas re-encodes 'dec    %di' differently
L_001995:
        .byte 0x4e  # forced-kept: gas re-encodes 'dec    %si' differently
L_001996:
        .byte 0x53  # forced-kept: gas re-encodes 'push   %bx' differently
L_001997:
        .byte 0x21,0x00  # forced-kept: gas re-encodes 'and    %ax,(%bx,%si)' differently
