# line — Bresenham between the four coordinate registers [DS:479..47C]
# name-evidence: called by all twelve dungeon shape routines and by nothing else, and its
#           body is the two-branch integer line algorithm: `stc;cmc;sbb` for each delta, the
#           absolute value kept in [DS:483]/[DS:484] and the step SIGN in [DS:47D]/[DS:47E],
#           then `cmp |dx|,|dy| ; jae` to pick the major axis and a plot call per step.
#           Renamed 2026-10-29 with CP7.
#           The plot it calls is asm/4B76; the registers are the same four asm/6078 and the
#           shape routines load, which is why a shape routine's first line can inherit a
#           coordinate from the routine before it.
#           PEN semantics, recorded 2026-11-01, and this is the part that was missed: the four
#           registers are a pen and a target, not two independent points. L_006a4b
#           (`adc %al,0x479`) and L_006a8f (`adc %al,0x47a`) step the CURRENT point once per
#           pixel of the major axis, so on return [DS:479]/[DS:47A] equal [DS:47B]/[DS:47C]
#           and the next call starts where this one ended. A caller that loads only
#           0x47B/0x47C is drawing from the previous endpoint, and asm/6425 does that three
#           times running. The engine transcription carried x1/y1 as "last value explicitly
#           written" instead of "pen", which is the whole of the CP7 residual wireframe
#           difference: asm/6425's right edge rendered as a top-left->bottom-right diagonal
#           and its bottom edge rendered as a left edge. 20 of 69 lines in a level-0 frame
#           were slanted; now 3 are, and all three are asm/66CB's chest lid, which is meant
#           to be.
# func 67B3..68A2  len 00F0 B  evidence: call+reko
# calls: L_004d76, L_0069ec, L_006a11, L_006a60
# provenance: static, read in full 2026-10-29 for CP7; the twelve callers are all in this
#           tree and the plot target asm/4B76 was read with it.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_67b3:
L_0069b3:
        nop
L_0069b4:
        mov    0x47b,%al
L_0069b7:
        cmp    0x479,%al
L_0069bb:
        jne L_0069c7
L_0069bd:
        mov    0x47c,%al
L_0069c0:
        cmp    0x47a,%al
L_0069c4:
        jne L_0069c7
L_0069c6:
        ret
L_0069c7:
        stc
L_0069c8:
        mov    0x47b,%al
L_0069cb:
        cmc
L_0069cc:
        sbb    0x479,%al
L_0069d0:
        cmc
L_0069d1:
        mov    %al,0x483
L_0069d4:
        jb L_0069e7
L_0069d6:
        xor    $0xff,%al
L_0069d8:
        mov    %al,0x483
L_0069db:
        incb   0x483
L_0069df:
        mov    $0xff,%al
L_0069e1:
        mov    %al,0x47d
L_0069e4:
        jmp L_0069ec
L_0069e6:
        nop
L_0069e7:
        mov    $0x1,%al
L_0069e9:
        mov    %al,0x47d
L_0069ec:
        stc
L_0069ed:
        mov    0x47c,%al
L_0069f0:
        cmc
L_0069f1:
        sbb    0x47a,%al
L_0069f5:
        cmc
L_0069f6:
        mov    %al,0x484
L_0069f9:
        jb L_006a0c
L_0069fb:
        xor    $0xff,%al
L_0069fd:
        mov    %al,0x484
L_006a00:
        incb   0x484
L_006a04:
        mov    $0xff,%al
L_006a06:
        mov    %al,0x47e
L_006a09:
        jmp L_006a11
L_006a0b:
        nop
L_006a0c:
        mov    $0x1,%al
L_006a0e:
        mov    %al,0x47e
L_006a11:
        mov    0x483,%al
L_006a14:
        cmp    0x484,%al
L_006a18:
        jae L_006a1d
L_006a1a:
        jmp L_006a60
L_006a1c:
        nop
L_006a1d:
        mov    0x483,%al
L_006a20:
        mov    %al,0x480
L_006a23:
        clc
L_006a24:
        rcr    $1,%al
L_006a26:
        mov    %al,0x481
L_006a29:
        clc
L_006a2a:
        mov    0x481,%al
L_006a2d:
        adc    0x484,%al
L_006a31:
        mov    %al,0x481
L_006a34:
        stc
L_006a35:
        cmc
L_006a36:
        sbb    0x483,%al
L_006a3a:
        cmc
L_006a3b:
        jae L_006a4b
L_006a3d:
        mov    %al,0x481
L_006a40:
        clc
L_006a41:
        mov    0x47a,%al
L_006a44:
        adc    0x47e,%al
L_006a48:
        mov    %al,0x47a
L_006a4b:
        clc
L_006a4c:
        mov    0x479,%al
L_006a4f:
        adc    0x47d,%al
L_006a53:
        mov    %al,0x479
L_006a56:
        call L_004d76
L_006a59:
        decb   0x480
L_006a5d:
        jne L_006a29
L_006a5f:
        ret
L_006a60:
        mov    0x484,%al
L_006a63:
        mov    %al,0x480
L_006a66:
        clc
L_006a67:
        rcr    $1,%al
L_006a69:
        mov    %al,0x481
L_006a6c:
        clc
L_006a6d:
        mov    0x481,%al
L_006a70:
        adc    0x483,%al
L_006a74:
        mov    %al,0x481
L_006a77:
        stc
L_006a78:
        cmc
L_006a79:
        sbb    0x484,%al
L_006a7d:
        cmc
L_006a7e:
        jae L_006a8e
L_006a80:
        mov    %al,0x481
L_006a83:
        clc
L_006a84:
        mov    0x479,%al
L_006a87:
        adc    0x47d,%al
L_006a8b:
        mov    %al,0x479
L_006a8e:
        clc
L_006a8f:
        mov    0x47a,%al
L_006a92:
        adc    0x47e,%al
L_006a96:
        mov    %al,0x47a
L_006a99:
        call L_004d76
L_006a9c:
        decb   0x480
L_006aa0:
        jne L_006a6c
L_006aa2:
        ret
