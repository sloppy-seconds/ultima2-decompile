# sub_4f64 — the swallow's body: AL := 0 and return with AH = 0xFF, i.e. "a key was consumed"
#           but no character is delivered. The caller sees a key that does nothing.
# func 4F64..4F68  len 0005 B  evidence: seed+reko
# calls: L_0051d1
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f64:
L_005164:
        mov    $0x0,%al
L_005166:
        jmp L_0051d1
L_005168:
        nop
