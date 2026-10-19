# cmd_F — command handler 'F': prints "FIRE" then falls
#           through into the following map fragment
# func 35C1..35C8  len 008 B  evidence: seed+reko (jump table cs:0730 entry F)
# confidence: high (handler role proven; message literal)
cmd_F:
        call L_0051df          # str_out — prints the inline string below
        db "FIRE",0        # string
