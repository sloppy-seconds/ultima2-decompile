# cmd_P — command handler 'P': prints "PASS" then falls
#           through into the following map fragment
# func 3DBC..3DC3  len 008 B  evidence: seed+reko (jump table cs:0730 entry P)
# confidence: high (handler role proven; message literal)
cmd_P:
        call L_0051df          # str_out — prints the inline string below
        db "PASS",0        # string
