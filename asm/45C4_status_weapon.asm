# status_weapon — status line: weapon count
# name-evidence: string '  WEAPON-'
# func 45C4..45D0  len 000D B  evidence: seed+reko
# strings: "  WEAPON-"
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
status_weapon:
L_0047c4:
        call L_0051df
        db "  WEAPON-",0x00        # string
