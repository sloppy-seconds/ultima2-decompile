# shop_header_armour — shop inventory header: armour
# name-evidence: string 'ARMOUR: '
# func 47A2..47AD  len 000C B  evidence: seed+reko
# strings: "ARMOUR: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_armour:
L_0049a2:
        call L_0051df
        db "ARMOUR: ",0x00        # string
