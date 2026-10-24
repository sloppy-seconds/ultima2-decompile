# sub_21a3 — the DS:26A clause of asm/2199_creature_step_gate: while DS:26A is non-zero EVERY
#           step is refused, for every species and every tile. The only non-zero writer is
#           asm/3C04_coin_rub, which sets 0x14 (20); asm/080D zeroes it with the legs/arms/
#           sleep counters and asm/0C33..0C53 ticks it down with them.
# func 21A3..21A5  len 0003 B  evidence: seed+reko
# calls: L_0023fc
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21a3:
L_0023a3:
        jmp L_0023fc
L_0023a5:
        nop
