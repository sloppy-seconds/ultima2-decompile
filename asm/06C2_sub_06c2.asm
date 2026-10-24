# sub_06c2 — part of asm/06AC_clock_tick_wait: `cmp $0x0,%al ; jne 06AC`. INT 1Ah AH=00 returns
#           the midnight-rollover count in AL, so a non-zero AL means the tick wrapped mid-read
#           and the whole window restarts from scratch. Fragment; read the owner.
# func 06C2..06C5  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06c2:
L_0008c2:
        cmp    $0x0,%al
L_0008c4:
        jne L_0008ac
