# rand_byte — pseudo-random byte: adc-mixes tick counters DS:0240/0243/0244
# name-evidence: 30 call sites incl. cmd_G item rolls; reads three DS tick bytes with stc/adc chain
# func 5217..522A  len 0014 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
rand_byte:
L_005417:
        push   %ax
L_005418:
        push   %bx
L_005419:
        stc
L_00541a:
        mov    0x240,%al
L_00541d:
        adc    0x243,%al
L_005421:
        adc    0x244,%al
L_005425:
        mov    %al,0x23f
L_005428:
        mov    $0x4,%bx
