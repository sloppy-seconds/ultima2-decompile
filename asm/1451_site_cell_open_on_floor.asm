# site_cell_open_on_floor — "is the cell at the player's site coordinates on floor AL EMPTY?"
#           AX = word[DS:472] + AL*256, offset = DS:24*16 + DS:23 (four `add al,al` then
#           `adc 0x23,%al`), read the byte, `or al,al`, ret. So ZF set means the byte is 0.
# name-evidence: the addressing is the same page arithmetic as asm/68C0_dungeon_grid_byte, and
#           every caller is a movement or teleport validity test: the UP/DOWN LADDER arms of
#           asm/3139 pass the CANDIDATE floor, and the BLINK arm passes the current one.
#           Confirmed live 2026-10-29 in captures/spice86/d12-ladder-ds25: in the sector-24
#           tower the ladder spells failed while the candidate floor's byte at DS:23/24 was
#           0x80 (wall) and succeeded at a cell where it was 0x00, moving DS:25 by one.
#           Note the callers fail on `jne`, i.e. on ZF CLEAR, so a NON-ZERO cell is the
#           rejection: this routine answers "open?", not "exists?".
# func 1451..147E  len 002E B  evidence: call+reko
# provenance: live:d12-ladder-ds25 (a live pass and a live fail of its test, 2026-10-29);
#           static bytes + measured cross-check against asm/68C0's identical page arithmetic
# confidence: high (bytes, the asm/68C0 cross-check, and a live pass and a live fail)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1451:
L_001651:
        nop
L_001652:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_001654:
        mov    $0x0,%al
L_001656:
        add    0x472,%ax
L_00165a:
        mov    %ah,0x9
L_00165e:
        mov    0x24,%al
L_001661:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001663:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001665:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001667:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001669:
        adc    0x23,%al
L_00166d:
        mov    %al,0x8
L_001670:
        mov    $0x0,%bh
L_001672:
        mov    $0x0,%bl
L_001674:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_001676:
        mov    0x8,%bx
L_00167a:
        mov    (%bx,%si),%al
L_00167c:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00167e:
        ret
