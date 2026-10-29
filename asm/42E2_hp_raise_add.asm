# hp_raise_add — the packed-decimal add that actually raises HP, and the end of the tribute
# name-evidence: `clc ; mov 0x51,%al ; adc 0x1f,%al ; daa ; mov 0x51,%al` then `jmp cmd_done`.
#           Adds the rung value from [DS:1F] to the HIGH byte of HP only, in packed decimal, so
#           a rung of 3 is +300 and the low two digits are untouched. Observed across 54 offers:
#           the trailing '01' of the seeded HP survived the whole climb from 0001 to 9901.
# func 42E2..42F0  len 000F B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_000c33
# provenance: live:lord-british-tribute, static
# confidence: high
# notes: only [DS:51] is read and written — [DS:52], the low byte, is never consulted. Anyone
#           "tidying" this into a 16-bit add would change the mechanic.
# label: sub_42e2 / L_0044e2 kept as they are — labels are body (AGENTS.md § 3).
sub_42e2:
L_0044e2:
        clc
L_0044e3:
        mov    0x51,%al
L_0044e6:
        adc    0x1f,%al
L_0044ea:
        daa
L_0044eb:
        mov    %al,0x51
L_0044ee:
        jmp L_000c33
