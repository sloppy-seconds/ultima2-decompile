# shop_header_items — shop inventory header: items
# name-evidence: string 'ITEMS: '
# func 4853..485D  len 000B B  evidence: seed+reko
# strings: "ITEMS: "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_items:
L_004a53:
        call L_0051df
        db "ITEMS: ",0x00        # string
