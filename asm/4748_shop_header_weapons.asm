# shop_header_weapons — shop inventory header: weapons
# name-evidence: string 'WEAPONS: '
# func 4748..4754  len 000D B  evidence: seed+reko
# strings: "WEAPONS: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_weapons:
L_004948:
        call L_0051df
        db "WEAPONS: ",0x00        # string
