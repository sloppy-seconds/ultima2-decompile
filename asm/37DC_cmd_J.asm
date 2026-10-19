# cmd_J — command handler 'J': prints "JUMP...WHEE..." then returns to the
#           dispatcher (jmp 0xc33). Trailing 0xe8 is a stop-trunc call opcode
#           whose operand lives in the next map fragment (37F1).
# func 37DC..37F0  len 021 B  evidence: seed+reko (jump table cs:0730 entry J)
# confidence: high
cmd_J:
        call L_0051df          # str_out — prints the inline string below
        db "JUMP...WHEE...",0   # string
        jmp L_000c33           # return to dispatcher
