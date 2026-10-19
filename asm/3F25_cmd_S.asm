# cmd_S — command handler 'S': prints "STEAL DIRECT-" then falls through
# func 3F25..3F35  len 017 B  evidence: seed+reko (jump table cs:0730 entry S)
# confidence: high
cmd_S:
        call L_0051df          # str_out — prints the inline string below
        db "STEAL DIRECT-",0   # string
