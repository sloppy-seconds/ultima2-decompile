# arrow_scancode_table — the four arrow scancodes and the direction codes they become.
#           DATA, not code. This is the CS:0x4F09 table the runbooks cite.
# body corrected: 2026-10-25 -- evidence: the eight bytes at file 0x5109 were disassembled as
#           `dec %ax ; push %cs ; push %ax ; sbb %cx,0x5(%di) ; dec %bx ; pop %ss`, which is not
#           a plausible instruction sequence and is not what the bytes are. They are four
#           (scancode, direction code) pairs and the scancodes are the IBM PC arrows: 0x48 up,
#           0x50 down, 0x4d right, 0x4b left. tools/assemble_clean.sh re-assembles them
#           byte-identically.
# name-evidence: docs/tooling-procedures.md records the reader as `cmp %cs:0x4f09(%bx),%ah`
#           then `mov %cs:0x4f0a(%bx),%al`, so the table is matched on AH (the scancode) and
#           never on AL; docs/phase4-plan.md CP4 records the four pairs and that the codes land
#           as data at DS:26E..271, which is what the walk loop's four arms compare against.
#           This file exists so that a citation of CS:0x4F09 has somewhere to point: until
#           2026-10-25 there was no asm/ file at that address at all.
# func 4F09..4F10  len 0008 B  evidence: re-derived from the image 2026-10-25
# provenance: static, from original/ultimaii.exe file 0x5109..0x5110
# confidence: high
L_005109:
        db 0x48,0x0e        # Up: scancode 0x48 -> direction code 0x0e
        db 0x50,0x19        # Down: scancode 0x50 -> direction code 0x19
        db 0x4d,0x05        # Right: scancode 0x4d -> direction code 0x05
        db 0x4b,0x17        # Left: scancode 0x4b -> direction code 0x17
