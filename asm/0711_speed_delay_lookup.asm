# speed_delay_lookup — read one of the 20 machine-scaled delay slots into %bx
# name-evidence: `mov 0x580(%bx),%bx` — %bx goes in as a byte offset into the word table at
#           DS:580 and comes out as the value stored there. The table is written by the rescale
#           routine at asm/06ED..0710 (`mov %ax,0x580(%bx)`), which fills offsets 0x00..0x26 in
#           steps of 2, i.e. exactly 20 slots. Callers set %bx to a small even constant first —
#           observed 0x00, 0x08, 0x0a, 0x14, 0x16, 0x18 — which is an index, not a value.
# WHY IT IS WORTH A NAME: this is the single read path for the whole speed system, and it is
#           called from FOURTEEN routines (asm/022E, 0696, 08C8, 2557, 2587, 2593, 277B,
#           38B0_cmd_L, 421A, 5F08, 6999_space_status, 6DFD_hyperwarp_flow, 7030_space_collision,
#           72A0). Whatever the game does at animation pace — the hyperwarp countdown, the space
#           status crawl, key-wait timeouts — it takes its timing from here.
# what the value is used as: a KEY-WAIT TIMEOUT, not an animation delay. The tell is what
#           follows the call at the sites that can be read: `call L_000911` then a wait whose
#           result is tested with `cmp $0xff,%ah` -- AH=0xFF is this project's own "no key"
#           marker, and the original's INT 16h AH=01h poll uses ZF the same way. So the slots
#           bound how long the game waits for input before moving on, which is exactly why the
#           measured values span 47 to 64,581: a title screen may linger and a collision check
#           may not.
# SLOT USAGE, from the 14 callers (bx is a BYTE offset; slot = bx/2):
#           bx=0x00  slot 0   (47)     asm/08C8, asm/277B (277B then `cmp $0xff,%ah`)
#           bx=0x04  slot 2   (64581)  asm/421A
#           bx=0x08  slot 4   (10090)  asm/022E
#           bx=0x0a  slot 5   (23)     asm/0696
#           bx=0x10  slot 8   (78)     asm/2557 (then `dec %di`), asm/2587
#           bx=0x12  slot 9   (32290)  asm/2593
#           bx=0x14  slot 10  (3784)   asm/6999_space_status, asm/7030_space_collision
#           bx=0x16  slot 11  (2522)   asm/6DFD_hyperwarp_flow
#           bx=0x1c  slot 14  (16145)  asm/38B0_cmd_L (two waits)
#           slots 1,3,6,7,12,13,15..19 have no caller found yet. asm/5F08 and asm/72A0 call
#           the lookup with a bx set outside the three lines grepped, so their slot is unknown.
#           This is a START, not an answer: it names which slot each site uses and what the
#           value is tested against, but not why each site picked that length.
# provenance: static, decoded 2026-10-28d from the listing; bytes proven by tools/check_func.py after the merge. The
#           DS:74 value itself is live: 0x3A17, static across 103 samples in
#           captures/spice86/g30-clockcal/.
# confidence: high for the mechanism and for the timeout reading of the value; the per-slot meaning of each of the 20
#           offsets is PARTIALLY known (see SLOT USAGE above) and the reason each site chose
#           its length is not
# label: kept as sub_0711 on purpose — labels are body and CP0 md5s them
# func 0711..0714  len 0004 B  evidence: seed+call+reko
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0711:
L_000911:
        mov    0x580(%bx),%bx
