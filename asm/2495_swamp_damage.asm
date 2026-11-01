# swamp_damage — subtract 5 HP, packed decimal, when the player enters a swamp tile
# name-evidence: the subtract itself. `stc; mov al,[DS:52]; cmc; sbb al,0x05; das; cmc;
#           mov [DS:52],al` then the same idiom with `sbb al,0x00` on [DS:51], then
#           `jb` to the death tail and `jmp L_000e62` otherwise. DS:51/DS:52 are the HP
#           BCD pair, so this is a fixed 5 HP cost with borrow, not a randomised hit —
#           it is NOT asm/0BDB_apply_hp_damage, whose amount is `(rand & [DS:22]) & 0x77 + 1`.
#           Reached only from asm/248B, which gates on mode 0x02 == map byte 0x04 (swamp).
#           OBSERVED live 2026-11-02: HP read at DS:51/52 across nine consecutive steps
#           went 0370 0365 0360 0355 0350 0345 0340 0335 0330 — every delta exactly -5.
#           OWNER control the same day: PASS while standing on swamp costs nothing,
#           safe->swamp costs 5, swamp->safe costs nothing, so the charge is for ENTERING.
#           Silent: the message log during the walk showed only PASS.
#           Renamed 2026-11-02 from sub_2495. Full table and the engine work still owed:
#           docs/handoff-tile-effects.md.
# func 2495..24B0  len 001C B  evidence: seed+reko
# calls: L_000e62
# confidence: medium (bytes proven by check_func.py; the meaning is observed live)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2495:
L_002695:
        stc
L_002696:
        mov    0x52,%al
L_002699:
        cmc
L_00269a:
        sbb    $0x5,%al
L_00269c:
        das
L_00269d:
        cmc
L_00269e:
        mov    %al,0x52
L_0026a1:
        mov    0x51,%al
L_0026a4:
        cmc
L_0026a5:
        sbb    $0x0,%al
L_0026a7:
        das
L_0026a8:
        cmc
L_0026a9:
        mov    %al,0x51
L_0026ac:
        jb L_0026b1
L_0026ae:
        jmp L_000e62
