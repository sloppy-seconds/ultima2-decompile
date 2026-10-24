# sub_215c — VERTICAL-ONLY candidate: DS:23 := mon_x, DS:24 keeps the candidate y. Re-fetch,
#           then asm/2166 re-gates. This and asm/216E are why a creature moves on one axis
#           when the diagonal tile refuses it (the per-species geometry measured live in
#           captures/spice86/cp5-g28-approach/).
# func 215C..2165  len 000A B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_215c:
L_00235c:
        mov    0x137(%di),%al
L_002360:
        mov    %al,0x23
L_002363:
        call L_0052b3
