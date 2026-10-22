# shop_header_spells — shop inventory header: spells
# name-evidence: string 'SPELLS: '
# func 47FA..4805  len 000C B  evidence: seed+reko
# strings: "SPELLS: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_spells:
L_0049fa:
        call L_0051df
        db "SPELLS: ",0x00        # string
