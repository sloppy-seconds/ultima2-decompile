# sub_2ff6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2FF6..2FFD  len 0008 B  evidence: seed+reko
# provenance: static (bytes) + live:shipcap3 — ' FRIGATE' is in that harvest's executed
#           print set (tools/cfg_printed.py) and its memory dump reads [DS:13] = 0x24 with
#           DS:E2 = 01, so the non-zero branch of this gate has been taken on camera. The
#           zero branch (asm/2FFE's refusal) has never run in any capture: every test
#           character used so far holds the item.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_2ff6, with the behaviour. This is the SHIP BOARDING GATE:
#           `mov 0xe2,%al ; or %al,%al ; jne L_003238`. Non-zero jumps to asm/3038, the
#           successful boarding; zero falls through into asm/2FFE, the crew's refusal.
#           DS:E2 is items_held[12] and docs/spice86-live-findings.md § 11 names slot 12 BLUE
#           TASSLE, which is the item the refusal implies. Reached from asm/2FAD when
#           [DS:14] == 0x24, i.e. when the player is standing on the ship tile 0x48.
sub_2ff6:
L_0031f6:
        nop
L_0031f7:
        mov    0xe2,%al
L_0031fa:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0031fc:
        jne L_003238
