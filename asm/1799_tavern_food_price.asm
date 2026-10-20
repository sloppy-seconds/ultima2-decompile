# tavern_food_price — quotes tavern food price
# name-evidence: string 'THE FOOD HERE COSTS '
# func 1799..17B1  len 0019 B  evidence: seed+reko
# strings: "THE FOOD HERE COSTS "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
tavern_food_price:
L_001999:
        nop
L_00199a:
        call L_0051df
        db "THE FOOD HERE COSTS ",0x00        # string
