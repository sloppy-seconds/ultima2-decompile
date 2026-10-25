# chatter_table_selector — picks entry SI out of a NUL-separated table and prints it
# name-evidence: read directly. Prologue sets ES=CS and loads DI from [DS:27:28] (the cursor);
#           the loop past this file's tiling range skips SI NULs and emits the entry it lands
#           on, one character per call to 0x53F4. asm/15E1's tail is the caller that points the
#           cursor at asm/16BD_barkeep_chatter_hints.asm, which is what this selects from.
# func 155D..1563  len 0007 B  evidence: call+reko
# note: this file holds only the PROLOGUE. The routine runs to about 0x1581 and the rest lives
#           in the following tiling fragments -- a known fragment split, see
#           disasm/fragment-splits.tsv and tools/fragment_splits.py. The name is on the entry
#           point, which is the file that owns it.
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 142 harvests that carry
#           an execution-flow dump; neither does its caller asm/15E1 nor the cursor write at
#           0x16a8, so the whole tavern path is read, not observed. Checked with the controls
#           0x4fdf (142/142), 0x0936 (107) and 0x0a1f (73) so the zero is not a parse failure.
# confidence: high (bytes proven by check_func.py; the cursor read and the walk are both read
#             directly, and the caller that sets DS:27:28 is at runtime 0x16a8..0x16af)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_155d:
L_00175d:
        push   %es
L_00175e:
        push   %cs
L_00175f:
        pop    %es
L_001760:
        mov    0x27,%di
