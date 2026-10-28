# sub_2708 — mechanical clean (bulk wave); behavior not yet reviewed
# DECODED 2026-10-29 from the listing. ATTRIBUTION REFUTED the same day: this is NOT the
#           time-door rotation, and an earlier version of this header claimed it was. A stop
#           armed at 17D:2908 across a window in which the gate demonstrably rotated twice
#           (DS:6E advanced and the 0xC0 stamp moved to a new cell) NEVER fired. The behaviour
#           is real and documented in docs/moongates.md; the routine that produces it is not
#           this one and is still undiscovered. Do not name this file after gates.
#           What survives: the decode below is what the bytes do, and the table this code
#           points at IS the gate table — 15/15 live gate cells match file 0x2998. So this
#           reads the right table on some path that was not taken during a rotation. Which
#           path, is open.
#           It computes the gate-table base and reads one candidate
#           coordinate pair: `clc ; mov 0x49,%al` then three forced-kept `add %al,%al` give
#           DS:1F = DS:49 * 8, `adc 0x6e,%al` gives the index DS:1F + DS:6E + CF, and
#           `%cs:0x2798(%di)` / `%cs:0x2798+1(%di)` load DS:23/DS:24 — a cell — before
#           `call L_0052b3` (asm/50B3, map tile pointer) looks up what is there.
#           Note the displacement-to-file direction: `%cs:0x2798` is file 0x2998, i.e.
#           file = displacement + 0x200, which is the OPPOSITE of the instruction-address
#           mapping used for the labels in this listing. Getting that backwards makes the
#           table read as garbage. Verified 12/12: byte offset 8*DS:49 + DS:6E from file
#           0x2998 gives the observed gate cell for every era and index watched live
#           (docs/moongates.md § 3).
# func 2708..2730  len 0029 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2708:
L_002908:
        clc
L_002909:
        mov    0x49,%al
L_00290c:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00290e:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002910:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002912:
        mov    %al,0x1f
L_002915:
        adc    0x6e,%al
L_002919:
        mov    $0x0,%ah
L_00291b:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_00291d:
        mov    %cs:0x2798(%di),%al
L_002922:
        mov    %al,0x23
L_002925:
        inc    %di
L_002926:
        mov    %cs:0x2798(%di),%al
L_00292b:
        mov    %al,0x24
L_00292e:
        call L_0052b3
