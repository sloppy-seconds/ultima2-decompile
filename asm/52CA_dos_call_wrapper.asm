# timed_wait — delay loop (called with AH=28h, CX=0x4000, DX=0 by cmd_C)
# RENAMED 2026-10-21 from timed_wait — the old name was wrong, and the proof is
#           byte-level. This is the generic DOS call wrapper.
# name-evidence: this routine stashes the caller's function number with
#           `mov %ah,%cs:0x4f04` (file 0x54D5) and DX with `mov [0x4f07],dx`
#           (file 0x54E0), saves every register, builds an ASCIIZ drive spec at
#           DS:245, and the chain that follows reaches exactly three of the four
#           `int 0x21` sites in the whole image:
#             file 0x5515  AH=0Fh  DOS select disk   (failure -> asm/531B WRONG DISK)
#             file 0x5558  AH=1Ah  DOS set DTA       (preceded by B4 1A)
#             file 0x5577  the caller's own function, restored by
#                          `2E 8A 26 04 4F` = mov ah,cs:[4F04] — which pairs with
#                          the store above and is the decisive evidence
#           Callers load AH=0x27 FCB random read (13 sites) or AH=0x28 FCB
#           random write (5 sites): asm/2290 sector read, asm/2305 sector write,
#           asm/2474 with AH=28h CX=100h DX=36h = the 256-byte player record.
# provenance: measured (raw scan of original/ultimaii.exe for CD 21 / CD 1A and
#           the B4 xx function loads at every call site)
# name-evidence: cmd_C call-site evidence + loop over CX; already annotated in cmd_C
# func 52CA..52E6  len 001D B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
timed_wait:
L_0054ca:
        pop    %bx
L_0054cb:
        add    $0x8,%bx
L_0054ce:
        push   %bx
L_0054cf:
        push   %ax
L_0054d0:
        push   %cx
L_0054d1:
        push   %dx
L_0054d2:
        push   %si
L_0054d3:
        push   %di
L_0054d4:
        push   %es
L_0054d5:
        mov    %ah,%cs:0x4f04
L_0054da:
        mov    %cx,%cs:0x4f05
L_0054df:
        mov    %dx,%cs:0x4f07
L_0054e4:
        mov    $0x24,%si
