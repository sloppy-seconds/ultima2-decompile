# sub_21ae — step gate, species clause 2: mon_type == 0x48 also goes to the water-only arm.
#           0x48 >> 2 == art 0x12, the frigate/ship. AL is still mon_type from asm/21A6.
# func 21AE..21B1  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21ae:
L_0023ae:
        cmp    $0x48,%al
L_0023b0:
        je L_0023d8
