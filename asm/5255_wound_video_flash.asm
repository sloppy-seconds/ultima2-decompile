# wound_video_flash — the screen effect that plays when the player is hit
# name-evidence: sets AX=0x90, BX=0x50 and passes the pattern table at runtime 0x5288 to
#           asm/4C1E, which XORs it into CGA video. Its ONLY two callers in the whole executable
#           are runtime 0x0BC6 and 0x0BCC, both inside the wound loop at 0x0BB2..0x0BCF, and it is
#           called twice in each iteration -- which is what an XOR flash needs, since the second
#           call undoes the first.
# callers: 0x0BC6 and 0x0BCC only.
# provenance: static, then OBSERVED LIVE 2026-11-02: captures/spice86/wound-flash-20261102 —
#           owner playtest, the flash caught by a 30 Hz poll of the CGA span. Three events,
#           byte-identical 56-byte masks, each coinciding with an HP drop at DS:51/52 (-3, -1,
#           -1), flash visible >=148-180 ms. The ON frame shows a white disc around the
#           player's centred sprite with the player inverted black inside it; the next frame
#           restores the span, exactly as the double-XOR predicts. The XOR mask matches the
#           table at runtime 0x5288 record for record, laid down at 80-byte scanline steps
#           across both CGA banks. This is also the first observation of the wound loop
#           (0x0BB2..0x0BCF) executing in any harvest.
#           RESOLVED (G56, same capture): the owner clarified -- "I flashed when he hit me,
#           and he flashed when I hit him" -- and a motif scan found the fourth event: frame
#           00257, the identical ring at span offset 2836 (five scanlines above the player's
#           3237), ~2.5 s after CMD: ATTACK-- enters the log. The ring marks the HIT UNIT'S
#           CELL in both directions. The mechanism fits: this routine is one of four fixed-
#           position wrappers (5255/525E/5267/5270) tail-calling the shared renderer asm/527F;
#           which variant the attack path uses is not yet identified (no callers of the other
#           three appear in asm/), and whether a MISS also flashes is untested.
# confidence: high for the mechanism (call graph, XOR, table all read directly) and now for
#             the visual result, previously "never been seen". The loop's trigger -- DS:20
#             contacts and DS:21 hits -- is now exercised live; whether the flash also rides
#             the player's attack path is open (G56).
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
