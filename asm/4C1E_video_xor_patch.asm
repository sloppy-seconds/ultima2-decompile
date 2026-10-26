# video_xor_patch — XOR a pattern table into CGA video memory
# name-evidence: read directly. SI = the caller's CX (a pattern table), DI = AX>>2 (an offset),
#           and each iteration loads a SEGMENT from cs:[BX+0x48DC] then does `es:[DI] ^= cs:[SI]`
#           and `es:[DI+2] ^= cs:[SI+2]`, 16 times, advancing both pointers. The segments that
#           table holds at the offsets this path uses are 0xB8C8, 0xBAC8, 0xB8CD, 0xBACD, 0xB8D2,
#           0xBAD2 ... — all inside the 0xB800 CGA range. So this writes pixels, not data.
#           XOR is its own inverse, which is exactly what a flash needs: call it twice and the
#           screen is restored.
# callers: exactly one, runtime 0x5284, which is inside asm/5255. Nothing else in the executable
#           reaches this routine.
# provenance: static
# confidence: high for the mechanism (the loop, the segment table and the XOR are all read
#             directly); the visual RESULT has not been observed, only inferred from the address
#             range being video. Treat "it flashes" as inferred, "it XORs video" as read.
# note: the declared range 4C1E..4C30 is a fragment boundary, not the routine. The loop body runs
#           to about 0x4C54 (the ret), so most of what this does lives in the following tiling
#           fragments. Known fragment split; see disasm/fragment-splits.tsv.
# func 4C1E..4C30  len 0013 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4c1e:
L_004e1e:
        push   %dx
L_004e1f:
        push   %di
L_004e20:
        push   %si
L_004e21:
        push   %es
L_004e22:
        .byte 0x8b,0xf1  # forced-kept: gas re-encodes 'mov    %cx,%si' differently
L_004e24:
        shr    $1,%ax
L_004e26:
        shr    $1,%ax
L_004e28:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004e2a:
        shl    $1,%bx
L_004e2c:
        mov    $0x10,%dl
L_004e2e:
        add    $0x2,%si
