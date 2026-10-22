# invalid_move_msg — rejects an invalid movement
# name-evidence: string '--INVALID MOVE!'
# func 0A02..0A14  len 0013 B  evidence: seed+reko
# strings: "--INVALID MOVE!"
# calls: L_0051df (str_out)
# provenance: live:play-test-live — observed firing on water (22 rejections) and
#           on mountain terrain; the engine's blocked-move echo cites this string
#           CORRECTION 2026-10-22: the string's execution is real and confirmed by
#           tools/cfg_printed.py, but the COUNT of 22 is not derivable from any
#           dump. ExecutedInstructions is a deduplicated address set — 0A02 appears
#           exactly once in every capture examined, regardless of rejects. The 22
#           traces to overworld.c's header comment, which F9 (docs/passability-
#           findings.md) already showed derives from the invalid vga-test dataset.
#           Treat "fires on a rejected step" as proven; treat "22" as unsupported.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
invalid_move_msg:
L_000c02:
        call L_0051df
        db "--INVALID MOVE!",0x00        # string
