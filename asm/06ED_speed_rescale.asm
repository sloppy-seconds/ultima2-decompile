# sub_06ed — head of the consumer of asm/06AC_clock_tick_wait's pass count: `mov $0x26,%bx`
#           selects a table entry, and asm/06F0 does `mov 0x74,%ax ; sub 0x554,%ax` then
#           `mulw 0x558(%bx) ; divw 0x554`. A count measured against a fixed 20-tick window,
#           multiplied and divided, is a machine-speed scale — INFERRED, nobody has dumped
#           DS:74 live. Also called from runtime 4FB3, so this is not startup-only.
# func 06ED..06EF  len 0003 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06ed:
L_0008ed:
        mov    $0x26,%bx
