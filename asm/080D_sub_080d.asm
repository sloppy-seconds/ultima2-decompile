# sub_080d — mechanical clean (bulk wave); behavior not yet reviewed
# func 080D..0838  len 002C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# READ 2026-10-29, and it changes what [DS:13] is. The first five instructions are
#           `mov 0x47,%al ; add %al,%al ; clc ; adc $0x78,%al ; mov %al,0x13`, i.e.
#           DS:13 = 0x78 + 2*pclass. The on-foot stamp is therefore CLASS-DEPENDENT:
#           0x78 fighter, 0x7A cleric, 0x7C wizard, 0x7E thief. Every capture in the corpus
#           reads 0x78 because every capture used a fighter, which is why 'DS:13 = 0x78 on
#           foot' has been written as a constant in half a dozen places.
#           CLASS NAMES CORRECTED the same day: this line said "mage" and "bishop", which are
#           neither of them words this binary uses. pool[72..75] in asm/4C55_name_pool.asm is
#           FIGHTER, CLERIC, WIZARD, THIEF, so class 1 is CLERIC (0x7A) and class 2 is WIZARD
#           (0x7C) — the reverse of what the informal names implied. tools/u2_edit.py carried
#           the same error as 'mage'/'paladin' and is fixed in the same commit.
#           What survives unchanged is the test every gate uses: the mounted check is
#           `cmp $0x78,%al` with the mounted arm on the `jb` side (asm/33A6, asm/44D4,
#           asm/2F96), and all four vehicle modes (0x22..0x28) are below 0x78 while all
#           four class values are at or above it. So 'below 0x78 means mounted' is right
#           for every class and the engine's uses of it stand.
#           The rest of the routine is an arrival tail: it zeroes the four counters at
#           DS:26A..26D (the three paralysis counters and the unnamed one), loads the entry
#           pair DS:5A/5B into DS:00/01, and then tests DS:69 — the same byte asm/38B0's
#           rocket branch writes, which makes this the most likely landing/return path for
#           a launched rocket.
#           CALLER NOT FOUND. Nothing in asm/ jumps or calls L_000a0d, and a byte scan of
#           the exe for near calls and jumps to that runtime address comes back empty, so
#           it is reached by fall-through from asm/080A, whose own label is equally
#           unreferenced. Where this runs is therefore UNPROVEN, and the engine does not
#           apply the class-dependent value for that reason: setting DS:13 from pclass at
#           sector entry would be a claim about a call site nobody has found. Recorded in
#           docs/needs-gameplay.md as a capture question.
sub_080d:
L_000a0d:
        mov    0x47,%al
L_000a10:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_000a12:
        clc
L_000a13:
        adc    $0x78,%al
L_000a15:
        mov    %al,0x13
L_000a18:
        mov    $0x0,%al
L_000a1a:
        mov    %al,0x26a
L_000a1d:
        mov    %al,0x26b
L_000a20:
        mov    %al,0x26c
L_000a23:
        mov    %al,0x26d
L_000a26:
        mov    0x5a,%al
L_000a29:
        mov    %al,0x0
L_000a2c:
        mov    0x5b,%al
L_000a2f:
        mov    %al,0x1
L_000a32:
        mov    0x69,%al
L_000a35:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000a37:
        je L_000a50
