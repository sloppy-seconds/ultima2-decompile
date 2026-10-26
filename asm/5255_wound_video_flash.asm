# wound_video_flash — the screen effect that plays when the player is hit
# name-evidence: sets AX=0x90, BX=0x50 and passes the pattern table at runtime 0x5288 to
#           asm/4C1E, which XORs it into CGA video. Its ONLY two callers in the whole executable
#           are runtime 0x0BC6 and 0x0BCC, both inside the wound loop at 0x0BB2..0x0BCF, and it is
#           called twice in each iteration -- which is what an XOR flash needs, since the second
#           call undoes the first.
# callers: 0x0BC6 and 0x0BCC only.
# provenance: static
#           the wound loop this sits in has not been observed executing in any harvest.
# confidence: medium. The call graph is proven (two callers, both in the wound loop) and the
#             mechanism is proven via asm/4C1E, but the visual result has never been seen and the
#             loop's own trigger -- DS:20 contacts and DS:21 hits -- has not been exercised live.
# note: the declared range 5255..525D stops before the `call 0x4C1E` at runtime 0x5284, so the
#           body extends into the following fragments. Known fragment split.
# func 5255..525D  len 0009 B  evidence: seed+call+reko
# calls: L_00547f
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5255:
L_005455:
        mov    $0x90,%ax
L_005458:
        mov    $0x50,%bx
L_00545b:
        jmp L_00547f
L_00545d:
        nop
