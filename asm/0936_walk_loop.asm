# walk_loop — overworld direction input, move-then-undo, and the reject echo
# name-evidence: live capture + full re-decode of file 0x0B36..0x0BF1 (2026-10-21).
#           Each arm: compare the direction code against the table at DS:26E..271,
#           then ACTUALLY MOVE (inc/dec [DS:00] or [DS:01]), echo the direction
#           word via call 0x51DF, load the mode byte (mov al,[DS:15] at 0x0962 or
#           mov al,[DS:18] at 0x09AF), call 0x2423, and on a nonzero return UNDO
#           the step and jmp 0x0A02 which prints --INVALID MOVE!. The undo happens
#           before any redraw, so a rejected step is a no-op on screen even though
#           the player did move. Accept tail at 0x09E9 xors DS:26 with 0xFF.
# arms: N 0x0955/undo 0x096C  S 0x097C/undo 0x0993  W 0x09A3/undo 0x09B9  E 0x09C9/undo 0x09DF
# provenance: live:create-test-live, live:play-test-live
# confidence: high for the flow; the tile-dependence of 0x2423 is still open,
#           see docs/passability-findings.md F1..F3
# func 0936..093F  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0936:
L_000b36:
        mov    %al,0x5d
L_000b39:
        mov    0x5d,%al
L_000b3c:
        cmp    $0x20,%al
L_000b3e:
        jne L_000b4f
