# char_print — display character in AL with CR special-casing; command-loop entry
# name-evidence: and 0x7F / cmp 0x0D prologue; target of char_print_wrap and cmd_done chain; fan-in 10
# func 5003..500C  len 000A B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
char_print:
L_005203:
        push   %bx
L_005204:
        push   %cx
L_005205:
        push   %dx
L_005206:
        push   %ax
L_005207:
        and    $0x7f,%al
L_005209:
        cmp    $0xd,%al
L_00520b:
        jne L_005216
