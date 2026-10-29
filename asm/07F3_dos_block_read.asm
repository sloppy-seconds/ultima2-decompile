# dos_block_read — a DOS AH=27h random-block read into the buffer at [DS:474]
# name-evidence: the body is `mov $0x800,%cx ; mov [DS:474],%dx ; mov $0x27,%ah ;
#           call L_0054ca`, i.e. int 21h function 27h with CX = 2048 and the transfer
#           address taken from [DS:474]. That single fact is what identifies the dungeon
#           sprite source: the live DS at 0x2900 is byte-identical to the shipped
#           `monsters` file, so 0x2900 is this routine's destination and [DS:474] is a
#           disk-transfer register that asm/68ED later reuses as a base pointer.
#           Renamed 2026-10-29; body untouched.
#           The 0x800 read length is also why the engine loads 2048 of the file's 2176
#           bytes: the trailing 128 are never transferred by the original.
# func 07F3..0806  len 0014 B  evidence: seed+reko
# calls: L_0054ca
# provenance: static, read in full 2026-10-29; the destination identity is confirmed
#           against captures/spice86/dungeon-35-live's live DS at 0x2900.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07f3:
L_0009f3:
        mov    $0x800,%cx
L_0009f6:
        mov    0x474,%dx
L_0009fa:
        mov    $0x27,%ah
L_0009fc:
        call L_0054ca
L_0009ff:
        dec    %bp
L_000a00:
        dec    %di
L_000a01:
        dec    %si
L_000a02:
        push   %bx
L_000a03:
        push   %sp
L_000a04:
        inc    %bp
L_000a05:
        push   %dx
L_000a06:
        push   %bx
