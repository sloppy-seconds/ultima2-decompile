# cmd_done — prints CR (AL=0x0D) via char_print and re-enters the command loop
# name-evidence: 59 command-handler returns jump here (jmp L_000c33); body loads 0x0D and tail-calls char_print
# func 0A33..0A37  len 0005 B  evidence: seed+reko
# calls: L_0055f4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cmd_done:
L_000c33:
        mov    $0xd,%al
L_000c35:
        call L_0055f4
