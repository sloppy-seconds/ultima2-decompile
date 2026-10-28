# cmd_N — command handler 'N': prints "NEGATE TIME" then falls through
# func 3BCE..3BDC  len 015 B  evidence: seed+reko (jump table cs:0730 entry N)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 171 harvests; derived by tools/provenance_from_traces.py
# confidence: high (message literal; fallthrough into next fragment)
cmd_N:
        call L_0051df          # str_out — prints the inline string below
        db "NEGATE TIME",0     # string
