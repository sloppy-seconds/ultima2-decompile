# sub_013b — part of the same split startup routine as asm/0133: call the consumer of the
#           clock window's pass count (`call L_0008ed`, i.e. asm/06ED). Reached by fallthrough
#           from the `call` at runtime 0138, not by any call or jump — see asm/0133.
# func 013B..013D  len 0003 B  evidence: seed+reko
# calls: L_0008ed
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_013b:
L_00033b:
        call L_0008ed
