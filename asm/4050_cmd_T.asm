# cmd_T — command handler 'T': prints "TRANSACT-" then falls through
# func 4050..405C  len 013 B  evidence: seed+reko (jump table cs:0730 entry T)
# provenance: live:airport (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: high
cmd_T:
        call L_0051df          # str_out — prints the inline string below
        db "TRANSACT-",0       # string
