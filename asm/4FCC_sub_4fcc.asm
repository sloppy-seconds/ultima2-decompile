# sub_4fcc — arrow-table hit: AL := the mapped direction code from CS:0x4F0A(bx). The four
#           codes are 0x0E north, 0x19 south, 0x05 east, 0x17 west, and the walk loop compares
#           them against the four data bytes at DS:26E..271 (initialised to `0e 19 05 17` in
#           the DS image at file 0x787E, confirmed by captures/spice86/live-ds-4f4d.bin).
# func 4FCC..4FD0  len 0005 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fcc:
L_0051cc:
        mov    %cs:0x4f0a(%bx),%al
