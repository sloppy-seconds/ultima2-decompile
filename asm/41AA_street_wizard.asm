# street_wizard — wizard street response
# name-evidence: string 'A WIZARD SAYS:'
# func 41AA..41D1  len 0028 B  evidence: seed+reko
# strings: "A WIZARD SAYS:"
# calls: L_0051df (str_out)
# provenance: live:airport (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
street_wizard:
L_0043aa:
        call L_0051df
        db "A WIZARD SAYS:",0x0d,"HEX-E-POO-HEX-ON-YOU!",0x00        # string
