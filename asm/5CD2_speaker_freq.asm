# speaker_freq — latches timer channel-2 frequency to the speaker (out 0x42 x2 + control)
# name-evidence: two out-immediates to port 0x42 (8253 PIT channel 2 counter latch)
# func 5CD2..5CD9  len 0008 B  evidence: seed+call+reko
# provenance: live:airport (+37 other harvests), static
#           entry executed in 38 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
speaker_freq:
L_005ed2:
        .byte 0x8b,0xc3  # forced-kept: gas re-encodes 'mov    %bx,%ax' differently
L_005ed4:
        out    %al,$0x42
L_005ed6:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_005ed8:
        out    %al,$0x42
