# cmd_U — command handler 'U': prints "UNLOCK DIRECTION-" then falls through
# func 42F1..4305  len 021 B  evidence: seed+reko (jump table cs:0730 entry U)
# confidence: high
cmd_U:
        call L_0051df          # str_out — prints the inline string below
        db "UNLOCK DIRECTION-",0    # string
