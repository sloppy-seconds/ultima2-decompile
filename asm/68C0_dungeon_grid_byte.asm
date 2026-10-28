# dungeon_grid_byte — read one byte of the DUNGEON grid at flat offset [DS:25]*256 + [DS:24]*16 + [DS:23]
# name-evidence: addressing decoded from the body (measured). AH=[DS:25]; AX=word[DS:472]+[DS:25]*256;
#           [DS:488]=AH (page/high byte). AL=[DS:24]*16 (four add %al,%al) adc [DS:23] -> [DS:487]
#           (row*16+col, low byte). Returns byte at DS:word[DS:487]. So the address is
#           word[DS:472] + [DS:25]*256 + [DS:24]*16 + [DS:23], i.e. the map-grid buffer read as a
#           16-wide grid with a 256-byte page selector [DS:25]. word[DS:472]=0x1800 in every live
#           capture (measured), the same buffer map_tile_ptr (asm/50B3) reads as the 64-wide sector
#           grid via y*64+x. This routine is NOT the sector-tile lookup: it is reached only from the
#           dungeon path (asm/6000 <- asm/1151 dungeon_darkness; asm/6078 <- asm/6000), and the
#           dungeon map mapx35 decomposes into 16 pages of 16x16 cells that all use the same 7
#           dungeon bytes (measured), with dungeon player/monster coords in 0..15 (measured).
#           The "y*16+x against a 64-wide grid" anomaly in docs/spice86-live-findings.md S12 is
#           resolved: the array is the dungeon grid (16-wide, paged by [DS:25]), not the overworld
#           sector grid. [DS:25] as a floor/page selector is PROVEN 2026-10-29: the ladder
#           spells move [DS:25] by one and asm/1451_site_cell_open_on_floor reads the candidate
#           floor through exactly this page arithmetic (capture: spice86/d12-ladder-ds25). A
#           tower's mapxNN is 16 pages of 256 bytes, matching the `cmp $0xf` bound on the byte.
# provenance: measured (asm/68C0 body + live DS dumps: word[DS:472]=0x1800, [DS:25]=0, dungeon
#           coords 0..15) + inferred (page/floor semantics of [DS:25])
# func 68C0..68EC  len 002D B  evidence: call+reko
# confidence: medium (addressing measured; [DS:25] page/floor role inferred, never observed nonzero)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68c0:
L_006ac0:
        mov    0x25,%ah
L_006ac4:
        mov    $0x0,%al
L_006ac6:
        add    0x472,%ax
L_006aca:
        mov    %ah,0x488
L_006ace:
        mov    0x24,%al
L_006ad1:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad3:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad5:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad7:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad9:
        adc    0x23,%al
L_006add:
        mov    %al,0x487
L_006ae0:
        mov    $0x0,%bh
L_006ae2:
        mov    $0x0,%bl
L_006ae4:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006ae6:
        mov    0x487,%bx
L_006aea:
        mov    (%bx,%si),%al
L_006aec:
        ret
