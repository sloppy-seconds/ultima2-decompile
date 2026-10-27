# vehicle_frigate — FRIGATE vehicle message branch
# name-evidence: string ' FRIGATE'
# func 3038..3044  len 000D B  evidence: seed+reko
# strings: " FRIGATE"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# CORRECTED 2026-10-29: this IS the ship boarding, and 'FRIGATE' is the game's name for
#           the ship you are allowed to take. asm/2FF6 reaches here when [DS:E2] is non-
#           zero, and the tail (transcribed as forced-keep bytes in asm/3048 at runtime
#           0x3245..0x3256, decoded against the raw exe) is:
#
#             mov $0x0,%al ; mov $0x0,%ah ; mov %ax,%si
#             mov 0x6,%bx                  ; bx = the cached map-cell pointer, DS:06
#             mov %al,(%bx,%si)            ; the cell becomes 0x00, open water
#             mov $0x24,%al ; mov %al,0x13 ; [DS:13] = the ship travel mode
#             jmp L_000c33                 ; cmd_done
#
#           So the ship tile is consumed and turned into water, which is why the ship then
#           'sails' from its own dock: the tile under the player is water, and asm/2619
#           accepts water only. The live sample is captures/spice86/ship-port-boniface,
#           where [DS:14] went 0x24 -> 0x00 on BOARD without the position moving.
#           The gate DS:E2 is items_held[12] = BLUE TASSLE (slot names:
#           docs/spice86-live-findings.md § 11, not derived here).
#           This closes the handoff's § 6 note that the frigate 'may not be a ship at
#           all': it sets the ship's mode byte and shares asm/2619's rule by construction,
#           because it IS the ship arm's success path.
#           Grade: bytes for every instruction above (re-read from original/ultimaii.exe,
#           not inferred from the gas re-encode), one measured live sample for the effect.
vehicle_frigate:
L_003238:
        nop
L_003239:
        call L_0051df
        db " FRIGATE",0x00        # string
