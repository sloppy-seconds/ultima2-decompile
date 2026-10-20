# sub_5400 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5400..5A65  len 0666 B  evidence: call+reko
# calls: L_000300, L_004c1c, L_00514d, L_0051df (str_out), L_005203, L_0053b0, L_0053eb, L_0054ca (+12 more)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5400:
L_005600:
        call L_004c1c
L_005603:
        db 0xb7,0x00  # split: branch target inside data
L_005605:
        db 0xb3,0x06  # split: branch target inside data
L_005607:
        db 0x8b,0xfb  # split: branch target inside data
L_005609:
        db 0xb7,0x00  # split: branch target inside data
L_00560b:
        db 0xb3,0x0c  # split: branch target inside data
L_00560d:
        db 0x8b,0xf3  # split: branch target inside data
L_00560f:
        call L_0053eb
L_005612:
        jmp L_00563b
L_005614:
        db 0xfb  # split: branch target inside data
L_005615:
        db 0x28,0x49,0x4e  # split: branch target inside data
L_005618:
        db 0x53  # split: branch target inside data
L_005619:
        db 0x45  # split: branch target inside data
L_00561a:
        db 0x52  # split: branch target inside data
L_00561b:
        db 0x54  # split: branch target inside data
L_00561c:
        db 0x20,0x41,0x20  # split: branch target inside data
L_00561f:
        db 0x42  # split: branch target inside data
L_005620:
        db 0x4c  # split: branch target inside data
L_005621:
        db 0x41  # split: branch target inside data
L_005622:
        db 0x4e  # split: branch target inside data
L_005623:
        db 0x4b  # split: branch target inside data
L_005624:
        db 0x20,0x50,0x4c  # split: branch target inside data
L_005627:
        db 0x41  # split: branch target inside data
L_005628:
        db 0x59  # split: branch target inside data
L_005629:
        db 0x45  # split: branch target inside data
L_00562a:
        db 0x52  # split: branch target inside data
L_00562b:
        db 0x20,0x44,0x49  # split: branch target inside data
L_00562e:
        db 0x53  # split: branch target inside data
L_00562f:
        db 0x4b  # split: branch target inside data
L_005630:
        db 0x29,0x0d  # split: branch target inside data
L_005632:
        db 0x00  # split: branch target inside data
L_005633:
        db 0xe8  # split: branch target inside data
L_005634:
        db 0x17  # split: branch target inside data
L_005635:
        db 0xfb  # split: branch target inside data
L_005636:
        db 0x3d,0x1b,0xff  # split: branch target inside data
L_005639:
        jne L_005633
L_00563b:
        db 0xb4,0x27  # split: branch target inside data
L_00563d:
        db 0xb9,0x00,0x01  # split: branch target inside data
L_005640:
        db 0x8d,0x16,0x36,0x00  # split: branch target inside data
L_005644:
        call L_0054ca
L_005647:
        db 0x50  # split: branch target inside data
L_005648:
        db 0x4c  # split: branch target inside data
L_005649:
        db 0x41  # split: branch target inside data
L_00564a:
        db 0x59  # split: branch target inside data
L_00564b:
        db 0x45  # split: branch target inside data
L_00564c:
        db 0x52  # split: branch target inside data
L_00564d:
        db 0x20,0x20  # split: branch target inside data
L_00564f:
        db 0x80,0x3e,0x36,0x00,0x00  # split: branch target inside data
L_005654:
        je L_005698
L_005656:
        call L_004c1c
L_005659:
        db 0xb7,0x00  # split: branch target inside data
L_00565b:
        db 0xb3,0x0b  # split: branch target inside data
L_00565d:
        db 0x8b,0xf3  # split: branch target inside data
L_00565f:
        db 0xb7,0x00  # split: branch target inside data
L_005661:
        db 0xb3,0x0e  # split: branch target inside data
L_005663:
        db 0x8b,0xfb  # split: branch target inside data
L_005665:
        call L_0053eb
L_005668:
        call L_0051df
        db 0x4e,0x4f,0x54,0x20,0x41,0x20,0x42,0x4c,0x41,0x4e,0x4b,0x00  # split: branch target inside data
L_005677:
        db 0xb7,0x00  # split: branch target inside data
L_005679:
        db 0xb3,0x0d  # split: branch target inside data
L_00567b:
        db 0x8b,0xf3  # split: branch target inside data
L_00567d:
        db 0xb7,0x00  # split: branch target inside data
L_00567f:
        db 0xb3,0x0e  # split: branch target inside data
L_005681:
        db 0x8b,0xfb  # split: branch target inside data
L_005683:
        call L_0053eb
L_005686:
        call L_0051df
        db 0x50,0x4c,0x41,0x59,0x45,0x52,0x20,0x44,0x49,0x53,0x4b,0x00  # split: branch target inside data
L_005695:
        jmp L_005c64
L_005698:
        call L_004c1c
L_00569b:
        call L_0051df
        db 0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x50,0x4c,0x41,0x59,0x45,0x52,0x20,0x47,0x45,0x4e,0x45,0x52,0x41,0x54,0x49,0x4f,0x4e,0x20,0x3a,0x00  # split: branch target inside data
L_0056bc:
        call L_0051df
        db 0x0d,0x0a,0x20,0x20,0x20,0x20,0x20,0x50,0x4f,0x49,0x4e,0x54,0x53,0x20,0x4c,0x45,0x46,0x54,0x20,0x54,0x4f,0x20,0x44,0x49,0x53,0x54,0x52,0x49,0x42,0x55,0x54,0x45,0x20,0x3a,0x20,0x00  # split: branch target inside data
L_0056e3:
        call L_0055df
L_0056e6:
        db 0xb0,0x90  # split: branch target inside data
L_0056e8:
        db 0xa2,0x29,0x00  # split: branch target inside data
L_0056eb:
        call L_0055b5
L_0056ee:
        call L_0055d9
L_0056f1:
        call L_0051df
        db 0x0d,0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x53,0x54,0x52,0x45,0x4e,0x47,0x54,0x48,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x41,0x47,0x49,0x4c,0x49,0x54,0x59,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x53,0x54,0x41,0x4d,0x49,0x4e,0x41,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x43,0x48,0x41,0x52,0x49,0x53,0x4d,0x41,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x57,0x49,0x53,0x44,0x4f,0x4d,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x2e,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x49,0x4e,0x54,0x45,0x4c,0x4c,0x49,0x47,0x45,0x4e,0x43,0x45,0x2e,0x2e,0x2e,0x0d,0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x4d,0x2f,0x46,0x2d,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x52,0x41,0x43,0x45,0x2d,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x54,0x59,0x50,0x45,0x2d,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x4e,0x41,0x4d,0x45,0x2d,0x0d,0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x53,0x41,0x54,0x49,0x53,0x46,0x41,0x43,0x54,0x4f,0x52,0x59,0x20,0x28,0x59,0x2f,0x4e,0x29,0x2d,0x0d,0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x52,0x41,0x43,0x45,0x53,0x3a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x54,0x59,0x50,0x45,0x53,0x3a,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x31,0x2d,0x48,0x55,0x4d,0x41,0x4e,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x31,0x2d,0x46,0x49,0x47,0x48,0x54,0x45,0x52,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x32,0x2d,0x45,0x4c,0x46,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x32,0x2d,0x43,0x4c,0x45,0x52,0x49,0x43,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x33,0x2d,0x44,0x57,0x41,0x52,0x46,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x33,0x2d,0x57,0x49,0x5a,0x41,0x52,0x44,0x0d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x34,0x2d,0x48,0x4f,0x42,0x42,0x49,0x54,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x34,0x2d,0x54,0x48,0x49,0x45,0x46,0x00  # split: branch target inside data
L_0058af:
        db 0xb7,0x00  # split: branch target inside data
L_0058b1:
        db 0xb3,0x04  # split: branch target inside data
L_0058b3:
        db 0x8b,0xf3  # split: branch target inside data
L_0058b5:
        db 0xb7,0x00  # split: branch target inside data
L_0058b7:
        db 0xb3,0x1a  # split: branch target inside data
L_0058b9:
        db 0x8b,0xfb  # split: branch target inside data
L_0058bb:
        call L_0053eb
L_0058be:
        call L_0053b0
L_0058c1:
        db 0xa2,0x4b,0x00  # split: branch target inside data
L_0058c4:
        call L_005c66
L_0058c7:
        db 0xb7,0x00  # split: branch target inside data
L_0058c9:
        db 0xb3,0x05  # split: branch target inside data
L_0058cb:
        db 0x8b,0xf3  # split: branch target inside data
L_0058cd:
        db 0xb7,0x00  # split: branch target inside data
L_0058cf:
        db 0xb3,0x1a  # split: branch target inside data
L_0058d1:
        db 0x8b,0xfb  # split: branch target inside data
L_0058d3:
        call L_0053eb
L_0058d6:
        call L_0053b0
L_0058d9:
        db 0xa2,0x4c,0x00  # split: branch target inside data
L_0058dc:
        call L_005c66
L_0058df:
        db 0xb7,0x00  # split: branch target inside data
L_0058e1:
        db 0xb3,0x1a  # split: branch target inside data
L_0058e3:
        db 0x8b,0xfb  # split: branch target inside data
L_0058e5:
        db 0xb7,0x00  # split: branch target inside data
L_0058e7:
        db 0xb3,0x06  # split: branch target inside data
L_0058e9:
        db 0x8b,0xf3  # split: branch target inside data
L_0058eb:
        call L_0053eb
L_0058ee:
        call L_0053b0
L_0058f1:
        db 0xa2,0x4d,0x00  # split: branch target inside data
L_0058f4:
        call L_005c66
L_0058f7:
        db 0xb7,0x00  # split: branch target inside data
L_0058f9:
        db 0xb3,0x07  # split: branch target inside data
L_0058fb:
        db 0x8b,0xf3  # split: branch target inside data
L_0058fd:
        db 0xb7,0x00  # split: branch target inside data
L_0058ff:
        db 0xb3,0x1a  # split: branch target inside data
L_005901:
        db 0x8b,0xfb  # split: branch target inside data
L_005903:
        call L_0053eb
L_005906:
        call L_0053b0
L_005909:
        db 0xa2,0x4e,0x00  # split: branch target inside data
L_00590c:
        call L_005c66
L_00590f:
        db 0xb7,0x00  # split: branch target inside data
L_005911:
        db 0xb3,0x1a  # split: branch target inside data
L_005913:
        db 0x8b,0xfb  # split: branch target inside data
L_005915:
        db 0xb7,0x00  # split: branch target inside data
L_005917:
        db 0xb3,0x08  # split: branch target inside data
L_005919:
        db 0x8b,0xf3  # split: branch target inside data
L_00591b:
        call L_0053eb
L_00591e:
        call L_0053b0
L_005921:
        db 0xa2,0x4f,0x00  # split: branch target inside data
L_005924:
        call L_005c66
L_005927:
        db 0xb7,0x00  # split: branch target inside data
L_005929:
        db 0xb3,0x1a  # split: branch target inside data
L_00592b:
        db 0x8b,0xfb  # split: branch target inside data
L_00592d:
        db 0xb7,0x00  # split: branch target inside data
L_00592f:
        db 0xb3,0x09  # split: branch target inside data
L_005931:
        db 0x8b,0xf3  # split: branch target inside data
L_005933:
        call L_0053eb
L_005936:
        call L_0053b0
L_005939:
        db 0xa2,0x50,0x00  # split: branch target inside data
L_00593c:
        call L_005c66
L_00593f:
        db 0xb7,0x00  # split: branch target inside data
L_005941:
        db 0xb3,0x14  # split: branch target inside data
L_005943:
        db 0x8b,0xfb  # split: branch target inside data
L_005945:
        db 0xb7,0x00  # split: branch target inside data
L_005947:
        db 0xb3,0x0b  # split: branch target inside data
L_005949:
        db 0x8b,0xf3  # split: branch target inside data
L_00594b:
        call L_0053eb
L_00594e:
        call L_0055d0
L_005951:
        db 0xa2,0x46,0x00  # split: branch target inside data
L_005954:
        db 0x3c,0x4d  # split: branch target inside data
L_005956:
        jne L_005981
L_005958:
        call L_0051df
        db 0x4d,0x41,0x4c,0x45,0x00  # split: branch target inside data
L_005960:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_005963:
        db 0x04,0x05  # split: branch target inside data
L_005965:
        db 0x27  # split: branch target inside data
L_005966:
        db 0xa2,0x4b,0x00  # split: branch target inside data
L_005969:
        db 0xb7,0x00  # split: branch target inside data
L_00596b:
        db 0xb3,0x1a  # split: branch target inside data
L_00596d:
        db 0x8b,0xfb  # split: branch target inside data
L_00596f:
        db 0xb7,0x00  # split: branch target inside data
L_005971:
        db 0xb3,0x04  # split: branch target inside data
L_005973:
        db 0x8b,0xf3  # split: branch target inside data
L_005975:
        call L_0053eb
L_005978:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_00597b:
        call L_0055b5
L_00597e:
        jmp L_0059ad
L_005980:
        db 0x90  # split: branch target inside data
L_005981:
        db 0x3c,0x46  # split: branch target inside data
L_005983:
        jne L_00594e
L_005985:
        call L_0051df
        db 0x46,0x45,0x4d,0x41,0x4c,0x45,0x00  # split: branch target inside data
L_00598f:
        db 0xa0,0x4e,0x00  # split: branch target inside data
L_005992:
        db 0x04,0x10  # split: branch target inside data
L_005994:
        db 0x27  # split: branch target inside data
L_005995:
        db 0xa2,0x4e,0x00  # split: branch target inside data
L_005998:
        db 0xb7,0x00  # split: branch target inside data
L_00599a:
        db 0xb3,0x1a  # split: branch target inside data
L_00599c:
        db 0x8b,0xfb  # split: branch target inside data
L_00599e:
        db 0xb7,0x00  # split: branch target inside data
L_0059a0:
        db 0xb3,0x07  # split: branch target inside data
L_0059a2:
        db 0x8b,0xf3  # split: branch target inside data
L_0059a4:
        call L_0053eb
L_0059a7:
        db 0xa0,0x4e,0x00  # split: branch target inside data
L_0059aa:
        call L_0055b5
L_0059ad:
        db 0xb7,0x00  # split: branch target inside data
L_0059af:
        db 0xb3,0x14  # split: branch target inside data
L_0059b1:
        db 0x8b,0xfb  # split: branch target inside data
L_0059b3:
        db 0xb7,0x00  # split: branch target inside data
L_0059b5:
        db 0xb3,0x0c  # split: branch target inside data
L_0059b7:
        db 0x8b,0xf3  # split: branch target inside data
L_0059b9:
        call L_0053eb
L_0059bc:
        call L_0055d0
L_0059bf:
        db 0xa2,0x48,0x00  # split: branch target inside data
L_0059c2:
        db 0x3c,0x31  # split: branch target inside data
L_0059c4:
        jne L_0059f0
L_0059c6:
        call L_0051df
        db 0x48,0x55,0x4d,0x41,0x4e,0x00  # split: branch target inside data
L_0059cf:
        db 0xa0,0x50,0x00  # split: branch target inside data
L_0059d2:
        db 0x04,0x05  # split: branch target inside data
L_0059d4:
        db 0x27  # split: branch target inside data
L_0059d5:
        db 0xa2,0x50,0x00  # split: branch target inside data
L_0059d8:
        db 0xb7,0x00  # split: branch target inside data
L_0059da:
        db 0xb3,0x1a  # split: branch target inside data
L_0059dc:
        db 0x8b,0xfb  # split: branch target inside data
L_0059de:
        db 0xb7,0x00  # split: branch target inside data
L_0059e0:
        db 0xb3,0x09  # split: branch target inside data
L_0059e2:
        db 0x8b,0xf3  # split: branch target inside data
L_0059e4:
        call L_0053eb
L_0059e7:
        db 0xa0,0x50,0x00  # split: branch target inside data
L_0059ea:
        call L_0055b5
L_0059ed:
        jmp L_005a79
L_0059f0:
        db 0x3c,0x32  # split: branch target inside data
L_0059f2:
        jne L_005a1c
L_0059f4:
        call L_0051df
        db 0x45,0x4c,0x46,0x00  # split: branch target inside data
L_0059fb:
        db 0xa0,0x4c,0x00  # split: branch target inside data
L_0059fe:
        db 0x04,0x05  # split: branch target inside data
L_005a00:
        db 0x27  # split: branch target inside data
L_005a01:
        db 0xa2,0x4c,0x00  # split: branch target inside data
L_005a04:
        db 0xb7,0x00  # split: branch target inside data
L_005a06:
        db 0xb3,0x1a  # split: branch target inside data
L_005a08:
        db 0x8b,0xfb  # split: branch target inside data
L_005a0a:
        db 0xb7,0x00  # split: branch target inside data
L_005a0c:
        db 0xb3,0x05  # split: branch target inside data
L_005a0e:
        db 0x8b,0xf3  # split: branch target inside data
L_005a10:
        call L_0053eb
L_005a13:
        db 0xa0,0x4c,0x00  # split: branch target inside data
L_005a16:
        call L_0055b5
L_005a19:
        jmp L_005a79
L_005a1b:
        db 0x90  # split: branch target inside data
L_005a1c:
        db 0x3c,0x33  # split: branch target inside data
L_005a1e:
        jne L_005a4a
L_005a20:
        call L_0051df
        db 0x44,0x57,0x41,0x52,0x46,0x00  # split: branch target inside data
L_005a29:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_005a2c:
        db 0x04,0x05  # split: branch target inside data
L_005a2e:
        db 0x27  # split: branch target inside data
L_005a2f:
        db 0xa2,0x4b,0x00  # split: branch target inside data
L_005a32:
        db 0xb7,0x00  # split: branch target inside data
L_005a34:
        db 0xb3,0x1a  # split: branch target inside data
L_005a36:
        db 0x8b,0xfb  # split: branch target inside data
L_005a38:
        db 0xb7,0x00  # split: branch target inside data
L_005a3a:
        db 0xb3,0x04  # split: branch target inside data
L_005a3c:
        db 0x8b,0xf3  # split: branch target inside data
L_005a3e:
        call L_0053eb
L_005a41:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_005a44:
        call L_0055b5
L_005a47:
        jmp L_005a79
L_005a49:
        db 0x90  # split: branch target inside data
L_005a4a:
        db 0x3c,0x34  # split: branch target inside data
L_005a4c:
        je L_005a51
L_005a4e:
        jmp L_0059ad
L_005a51:
        call L_0051df
        db 0x48,0x4f,0x42,0x42,0x49,0x54,0x00  # split: branch target inside data
L_005a5b:
        db 0xa0,0x4f,0x00  # split: branch target inside data
L_005a5e:
        db 0x04,0x10  # split: branch target inside data
L_005a60:
        db 0x27  # split: branch target inside data
L_005a61:
        db 0xa2,0x4f,0x00  # split: branch target inside data
L_005a64:
        db 0xb7,0x00  # split: branch target inside data
L_005a66:
        db 0xb3,0x1a  # split: branch target inside data
L_005a68:
        db 0x8b,0xfb  # split: branch target inside data
L_005a6a:
        db 0xb7,0x00  # split: branch target inside data
L_005a6c:
        db 0xb3,0x08  # split: branch target inside data
L_005a6e:
        db 0x8b,0xf3  # split: branch target inside data
L_005a70:
        call L_0053eb
L_005a73:
        db 0xa0,0x4f,0x00  # split: branch target inside data
L_005a76:
        call L_0055b5
L_005a79:
        db 0xf8  # split: branch target inside data
L_005a7a:
        db 0xa0,0x48,0x00  # split: branch target inside data
L_005a7d:
        db 0x2c,0x31  # split: branch target inside data
L_005a7f:
        db 0xa2,0x48,0x00  # split: branch target inside data
L_005a82:
        db 0xb7,0x00  # split: branch target inside data
L_005a84:
        db 0xb3,0x0d  # split: branch target inside data
L_005a86:
        db 0x8b,0xf3  # split: branch target inside data
L_005a88:
        db 0xb7,0x00  # split: branch target inside data
L_005a8a:
        db 0xb3,0x14  # split: branch target inside data
L_005a8c:
        db 0x8b,0xfb  # split: branch target inside data
L_005a8e:
        call L_0053eb
L_005a91:
        call L_0055d0
L_005a94:
        db 0xa2,0x47,0x00  # split: branch target inside data
L_005a97:
        db 0x3c,0x31  # split: branch target inside data
L_005a99:
        jne L_005ac7
L_005a9b:
        call L_0051df
        db 0x46,0x49,0x47,0x48,0x54,0x45,0x52,0x00  # split: branch target inside data
L_005aa6:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_005aa9:
        db 0x04,0x15  # split: branch target inside data
L_005aab:
        db 0x27  # split: branch target inside data
L_005aac:
        db 0xa2,0x4b,0x00  # split: branch target inside data
L_005aaf:
        db 0xb7,0x00  # split: branch target inside data
L_005ab1:
        db 0xb3,0x1a  # split: branch target inside data
L_005ab3:
        db 0x8b,0xfb  # split: branch target inside data
L_005ab5:
        db 0xb7,0x00  # split: branch target inside data
L_005ab7:
        db 0xb3,0x04  # split: branch target inside data
L_005ab9:
        db 0x8b,0xf3  # split: branch target inside data
L_005abb:
        call L_0053eb
L_005abe:
        db 0xa0,0x4b,0x00  # split: branch target inside data
L_005ac1:
        call L_0055b5
L_005ac4:
        jmp L_005b53
L_005ac7:
        db 0x3c,0x32  # split: branch target inside data
L_005ac9:
        jne L_005af6
L_005acb:
        call L_0051df
        db 0x43,0x4c,0x45,0x52,0x49,0x43,0x00  # split: branch target inside data
L_005ad5:
        db 0xa0,0x4f,0x00  # split: branch target inside data
L_005ad8:
        db 0x04,0x10  # split: branch target inside data
L_005ada:
        db 0x27  # split: branch target inside data
L_005adb:
        db 0xa2,0x4f,0x00  # split: branch target inside data
L_005ade:
        db 0xb7,0x00  # split: branch target inside data
L_005ae0:
        db 0xb3,0x1a  # split: branch target inside data
L_005ae2:
        db 0x8b,0xfb  # split: branch target inside data
L_005ae4:
        db 0xb7,0x00  # split: branch target inside data
L_005ae6:
        db 0xb3,0x08  # split: branch target inside data
L_005ae8:
        db 0x8b,0xf3  # split: branch target inside data
L_005aea:
        call L_0053eb
L_005aed:
        db 0xa0,0x4f,0x00  # split: branch target inside data
L_005af0:
        call L_0055b5
L_005af3:
        jmp L_005b53
L_005af5:
        db 0x90  # split: branch target inside data
L_005af6:
        db 0x3c,0x33  # split: branch target inside data
L_005af8:
        jne L_005b25
L_005afa:
        call L_0051df
        db 0x57,0x49,0x5a,0x41,0x52,0x44,0x00  # split: branch target inside data
L_005b04:
        db 0xa0,0x50,0x00  # split: branch target inside data
L_005b07:
        db 0x04,0x10  # split: branch target inside data
L_005b09:
        db 0x27  # split: branch target inside data
L_005b0a:
        db 0xa2,0x50,0x00  # split: branch target inside data
L_005b0d:
        db 0xb7,0x00  # split: branch target inside data
L_005b0f:
        db 0xb3,0x1a  # split: branch target inside data
L_005b11:
        db 0x8b,0xfb  # split: branch target inside data
L_005b13:
        db 0xb7,0x00  # split: branch target inside data
L_005b15:
        db 0xb3,0x09  # split: branch target inside data
L_005b17:
        db 0x8b,0xf3  # split: branch target inside data
L_005b19:
        call L_0053eb
L_005b1c:
        db 0xa0,0x50,0x00  # split: branch target inside data
L_005b1f:
        call L_0055b5
L_005b22:
        jmp L_005b53
L_005b24:
        db 0x90  # split: branch target inside data
L_005b25:
        db 0x3c,0x34  # split: branch target inside data
L_005b27:
        je L_005b2c
L_005b29:
        jmp L_005a79
L_005b2c:
        call L_0051df
        db 0x54,0x48,0x49,0x45,0x46,0x00  # split: branch target inside data
L_005b35:
        db 0xa0,0x4c,0x00  # split: branch target inside data
L_005b38:
        db 0x04,0x10  # split: branch target inside data
L_005b3a:
        db 0x27  # split: branch target inside data
L_005b3b:
        db 0xa2,0x4c,0x00  # split: branch target inside data
L_005b3e:
        db 0xb7,0x00  # split: branch target inside data
L_005b40:
        db 0xb3,0x1a  # split: branch target inside data
L_005b42:
        db 0x8b,0xfb  # split: branch target inside data
L_005b44:
        db 0xb7,0x00  # split: branch target inside data
L_005b46:
        db 0xb3,0x05  # split: branch target inside data
L_005b48:
        db 0x8b,0xf3  # split: branch target inside data
L_005b4a:
        call L_0053eb
L_005b4d:
        db 0xa0,0x4c,0x00  # split: branch target inside data
L_005b50:
        call L_0055b5
L_005b53:
        db 0xf8  # split: branch target inside data
L_005b54:
        db 0xa0,0x47,0x00  # split: branch target inside data
L_005b57:
        db 0x2c,0x31  # split: branch target inside data
L_005b59:
        db 0xa2,0x47,0x00  # split: branch target inside data
L_005b5c:
        db 0xb7,0x00  # split: branch target inside data
L_005b5e:
        db 0xb3,0x0e  # split: branch target inside data
L_005b60:
        db 0x8b,0xf3  # split: branch target inside data
L_005b62:
        db 0xb7,0x00  # split: branch target inside data
L_005b64:
        db 0xb3,0x14  # split: branch target inside data
L_005b66:
        db 0x8b,0xfb  # split: branch target inside data
L_005b68:
        call L_0053eb
L_005b6b:
        call L_0051df
        db 0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x00  # split: branch target inside data
L_005b7e:
        db 0xb7,0x00  # split: branch target inside data
L_005b80:
        db 0xb3,0x14  # split: branch target inside data
L_005b82:
        db 0x8b,0xfb  # split: branch target inside data
L_005b84:
        db 0xb7,0x00  # split: branch target inside data
L_005b86:
        db 0xb3,0x0e  # split: branch target inside data
L_005b88:
        db 0x8b,0xf3  # split: branch target inside data
L_005b8a:
        call L_0053eb
L_005b8d:
        db 0xb7,0x00  # split: branch target inside data
L_005b8f:
        db 0xb3,0x0e  # split: branch target inside data
L_005b91:
        db 0x8b,0xfb  # split: branch target inside data
L_005b93:
        db 0xb0,0x00  # split: branch target inside data
L_005b95:
        db 0x88,0x85,0x36,0x00  # split: branch target inside data
L_005b99:
        db 0x4f  # split: branch target inside data
L_005b9a:
        jne L_005b95
L_005b9c:
        db 0xb7,0x00  # split: branch target inside data
L_005b9e:
        db 0xb3,0x00  # split: branch target inside data
L_005ba0:
        db 0x8b,0xfb  # split: branch target inside data
L_005ba2:
        call L_0055d0
L_005ba5:
        db 0x3c,0x08  # split: branch target inside data
L_005ba7:
        je L_005b5c
L_005ba9:
        db 0x3c,0x0d  # split: branch target inside data
L_005bab:
        je L_005bbc
L_005bad:
        call L_005203
L_005bb0:
        db 0x88,0x85,0x36,0x00  # split: branch target inside data
L_005bb4:
        db 0x47  # split: branch target inside data
L_005bb5:
        db 0x8b,0xdf  # split: branch target inside data
L_005bb7:
        db 0x80,0xfb,0x0c  # split: branch target inside data
L_005bba:
        jb L_005ba2
L_005bbc:
        db 0xb7,0x00  # split: branch target inside data
L_005bbe:
        db 0xb3,0x10  # split: branch target inside data
L_005bc0:
        db 0x8b,0xf3  # split: branch target inside data
L_005bc2:
        db 0xb7,0x00  # split: branch target inside data
L_005bc4:
        db 0xb3,0x1d  # split: branch target inside data
L_005bc6:
        db 0x8b,0xfb  # split: branch target inside data
L_005bc8:
        call L_0053eb
L_005bcb:
        call L_0055d0
L_005bce:
        call L_005203
L_005bd1:
        db 0x3c,0x4e  # split: branch target inside data
L_005bd3:
        jne L_005bd8
L_005bd5:
        jmp L_005698
L_005bd8:
        db 0x3c,0x59  # split: branch target inside data
L_005bda:
        jne L_005bbc
L_005bdc:
        db 0xb0,0x14  # split: branch target inside data
L_005bde:
        db 0xa2,0x5a,0x00  # split: branch target inside data
L_005be1:
        db 0xb0,0x14  # split: branch target inside data
L_005be3:
        db 0xa2,0x5b,0x00  # split: branch target inside data
L_005be6:
        db 0xb0,0x02  # split: branch target inside data
L_005be8:
        db 0xa2,0x49,0x00  # split: branch target inside data
L_005beb:
        db 0xb0,0x04  # split: branch target inside data
L_005bed:
        db 0xa2,0x51,0x00  # split: branch target inside data
L_005bf0:
        db 0xa2,0x53,0x00  # split: branch target inside data
L_005bf3:
        db 0xa2,0x58,0x00  # split: branch target inside data
L_005bf6:
        db 0xb4,0x28  # split: branch target inside data
L_005bf8:
        db 0xb9,0x00,0x01  # split: branch target inside data
L_005bfb:
        db 0x8d,0x16,0x36,0x00  # split: branch target inside data
L_005bff:
        call L_0054ca
L_005c02:
        db 0x50  # split: branch target inside data
L_005c03:
        db 0x4c  # split: branch target inside data
L_005c04:
        db 0x41  # split: branch target inside data
L_005c05:
        db 0x59  # split: branch target inside data
L_005c06:
        db 0x45  # split: branch target inside data
L_005c07:
        db 0x52  # split: branch target inside data
L_005c08:
        db 0x20,0x20  # split: branch target inside data
L_005c0a:
        call L_004c1c
L_005c0d:
        db 0xb7,0x00  # split: branch target inside data
L_005c0f:
        db 0xb3,0x0b  # split: branch target inside data
L_005c11:
        db 0x8b,0xf3  # split: branch target inside data
L_005c13:
        db 0xb7,0x00  # split: branch target inside data
L_005c15:
        db 0xb3,0x0b  # split: branch target inside data
L_005c17:
        db 0x8b,0xfb  # split: branch target inside data
L_005c19:
        call L_0053eb
L_005c1c:
        jmp L_005c61
L_005c1e:
        db 0xf5  # split: branch target inside data
L_005c1f:
        db 0x54  # split: branch target inside data
L_005c20:
        db 0x4f  # split: branch target inside data
L_005c21:
        db 0x20,0x50,0x4c  # split: branch target inside data
L_005c24:
        db 0x41  # split: branch target inside data
L_005c25:
        db 0x59  # split: branch target inside data
L_005c26:
        db 0x20,0x55,0x4c  # split: branch target inside data
L_005c29:
        db 0x54  # split: branch target inside data
L_005c2a:
        db 0x49  # split: branch target inside data
L_005c2b:
        db 0x4d  # split: branch target inside data
L_005c2c:
        db 0x41  # split: branch target inside data
L_005c2d:
        db 0x20,0x5d,0x5b  # split: branch target inside data
L_005c30:
        db 0x00,0xb7,0x00,0xb3  # split: branch target inside data
L_005c34:
        db 0x0d,0x8b,0xf3  # split: branch target inside data
L_005c37:
        db 0xb7,0x00  # split: branch target inside data
L_005c39:
        db 0xb3,0x09  # split: branch target inside data
L_005c3b:
        db 0x8b,0xfb  # split: branch target inside data
L_005c3d:
        call L_0053eb
L_005c40:
        call L_0051df
        db 0x49,0x4e,0x53,0x45,0x52,0x54,0x20,0x50,0x52,0x4f,0x47,0x52,0x41,0x4d,0x20,0x4d,0x41,0x53,0x54,0x45,0x52,0x00  # split: branch target inside data
L_005c59:
        call L_00514d
L_005c5c:
        db 0x3d,0x1b,0xff  # split: branch target inside data
L_005c5f:
        jne L_005c59
L_005c61:
        call L_000300
L_005c64:
        jmp L_005c64
