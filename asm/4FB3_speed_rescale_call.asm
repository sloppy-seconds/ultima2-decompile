# speed_rescale_call — the join point where a speed change rebuilds the 20 delay slots
# name-evidence: three bytes, `call L_0008ed`, reached from BOTH directions of the speed control:
#           asm/4F8E_speed_slower_f8 jumps here after lowering DS:74, and asm/4FA5_speed_faster_f7
#           falls through here after raising it. asm/013B is the other caller, on the startup
#           path right after asm/06AC_clock_tick_wait fills DS:74 with the measured pass count.
# WHY THIS TINY FRAGMENT MATTERS: it is the evidence that the clock-window measurement is not
#           dead scratch. The same routine that recomputes the delay table when the user presses
#           a key is what the startup measurement hands its result to. So DS:74 is one variable
#           with two writers — a measured seed and a user override — and one consumer, the
#           rescaler at asm/06ED..0710, whose output asm/0711_speed_delay_lookup serves to
#           fourteen animation and timeout sites.
# CORRECTION 2026-10-28d, and it is a 0x200 error: `docs/phase4-implementation.md` § the key
#           handler note says the function keys "then call `asm/08ED`". They do not. The
#           instruction is `call L_0008ed`, and `L_0008ed` is a FILE offset — runtime 0x06ED,
#           which is this call target. Runtime 0x08ED is a different routine entirely
#           (asm/08ED_sub_08ed, which calls L_004ce6 and has nothing to do with speed). The note
#           read the label as a runtime address, which is the exact file-vs-runtime confusion the
#           +0x200 bias exists to cause. Fixed in that doc the same day.
# provenance: static, decoded 2026-10-28d from the listing; bytes proven by tools/check_func.py
# confidence: high
# label: kept as sub_4fb3 on purpose — labels are body and CP0 md5s them
# func 4FB3..4FB5  len 0003 B  evidence: reko
# calls: L_0008ed
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fb3:
L_0051b3:
        call L_0008ed
