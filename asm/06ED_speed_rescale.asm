# sub_06ed — head of the consumer of asm/06AC_clock_tick_wait's pass count: `mov $0x26,%bx`
#           selects a table entry, and asm/06F0 does `mov 0x74,%ax ; sub 0x554,%ax` then
#           `mulw 0x558(%bx) ; divw 0x554`. A count measured against a fixed 20-tick window,
#           multiplied and divided, is a machine-speed scale — INFERRED, nobody has dumped
#           DS:74 live. Also called from runtime 4FB3, so this is not startup-only.
# func 06ED..0710  len 0024 B  evidence: seed+call+reko
# name-evidence: the rescaler that asm/06AC_clock_tick_wait feeds and asm/4FB3_speed_rescale_call
#           calls. A 20-iteration loop (`mov $0x26,%bx` down to 0 in steps of 2) computing, per
#           slot, `(DS:74 - DS:554) * DS:558[i] / DS:554`, clamped to 0 when DS:74 < DS:554, and
#           storing at DS:580[i]. DS:74 is the game's speed setting; the 20 slots at DS:580 are
#           delay values served by asm/0711_speed_delay_lookup to fourteen animation and
#           key-timeout sites.
# provenance: static, decoded 2026-10-28d from original/ultimaii.exe file 0x08ED..0x0910,
#           instruction by instruction; bytes proven by tools/check_func.py after the merge. The
#           DS:74 value itself is live: 0x3A17, static across 103 samples in
#           captures/spice86/g30-clockcal/.
# confidence: high for the arithmetic and the loop shape; medium for what each of the 20 slot
#           offsets gates, which is still unknown
# MERGED 2026-10-28d from 6 fragments the Phase 2/3 wave cut out of one routine: 06F0 06F9 06FF 0707 0710. Body lines are concatenated in address order and none was edited; engine/tests/asm_body_guard.py requires the tree's assemblable content to be conserved, and it is.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06ed:
L_0008ed:
        mov    $0x26,%bx
sub_06f0:
L_0008f0:
        mov    0x74,%ax
L_0008f3:
        sub    0x554,%ax
L_0008f7:
        jae L_0008ff
sub_06f9:
L_0008f9:
        mov    $0x0,%ax
L_0008fc:
        jmp L_000907
L_0008fe:
        nop
sub_06ff:
L_0008ff:
        mulw   0x558(%bx)
L_000903:
        divw   0x554
sub_0707:
L_000907:
        mov    %ax,0x580(%bx)
L_00090b:
        sub    $0x2,%bx
L_00090e:
        jae L_0008f0
sub_0710:
L_000910:
        ret
