# sub_21d1 — step gate, tile clause: 0x70 (art 0x1C) is accepted. Measured: 12691 cells over
#           15 sectors, and in the *x1/*2/*3 sectors it forms the street and open-ground runs
#           between the 0x78 blocks — i.e. this is what lets creatures walk around in a town.
#           The name "town ground" is inferred from that distribution, not read from a byte.
# func 21D1..21D4  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21d1:
L_0023d1:
        cmp    $0x70,%al
L_0023d3:
        je L_0023e2
