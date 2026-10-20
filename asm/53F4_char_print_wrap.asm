# char_print_wrap — 3-byte tail-call wrapper into char_print
# name-evidence: body is a single call to L_005203 (char_print); 25 call sites
# func 53F4..53F6  len 0003 B  evidence: seed+call+reko
# calls: L_005203
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
char_print_wrap:
L_0055f4:
        call L_005203
