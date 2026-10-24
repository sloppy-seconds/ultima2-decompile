# sub_06da — part of asm/06AC_clock_tick_wait: the gate itself — `addw $0x1,0x74` counts the
#           pass, `sub 0x550,%dx` / `sub 0x552,%cx` forms the elapsed tick, `cmp $0x14,%dx`
#           with `jb 06CC` holds the window at 20 ticks. Fragment; read the owner.
# func 06DA..06EB  len 0012 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06da:
L_0008da:
        addw   $0x1,0x74
L_0008df:
        sub    0x550,%dx
L_0008e3:
        sub    0x552,%cx
L_0008e7:
        cmp    $0x14,%dx
L_0008ea:
        jb L_0008cc
