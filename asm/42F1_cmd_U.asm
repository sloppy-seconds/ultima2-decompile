# cmd_U — command handler 'U': prints "UNLOCK DIRECTION-" then falls through
# func 42F1..4305  len 021 B  evidence: seed+reko (jump table cs:0730 entry U)
# provenance: live:airport32 (+2 other harvests), static
#           entry executed in 3 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: high
cmd_U:
        call L_0051df          # str_out — prints the inline string below
        db "UNLOCK DIRECTION-",0    # string
