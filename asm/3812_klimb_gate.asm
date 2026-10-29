# klimb_gate — the cell-feature and site-kind switch that picks which way a floor moves
# name-evidence: reached only from asm/37F1 cmd_K after the kind has already been narrowed to 4
#           or 5. It tests `[DS:14] & 0x10` — the UP-ladder cell feature, the mirror of the
#           `& 0x20` DESCEND tests in asm/334D — and then branches on the kind: 4 goes to
#           asm/3381 (increment), anything else to asm/3823 (decrement). So the two vertical
#           commands are exact mirrors, and this file is the half of that symmetry which lives
#           on the KLIMB side.
# func 3812..3822  len 0011 B  evidence: reko; role read from the bytes 2026-10-29
# calls: L_003581
# provenance: static bytes. The 0x10 and 0x20 cell features were both measured in the sector-24
#           tower (captures/spice86/d12-ladder-ds25 for the down cell).
# confidence: high
# notes: a refusal here lands on L_003a05, which is inside asm/37F2 — the same `-WHAT?` the
#           out-of-site refusal uses, reached by jump rather than by fall-through.
# label: sub_3812 / L_003a12 kept as they are — labels are body (AGENTS.md § 3).
sub_3812:
L_003a12:
        mov    0x14,%al
L_003a15:
        and    $0x10,%al
L_003a17:
        je L_003a05
L_003a19:
        mov    0x4a,%al
L_003a1c:
        cmp    $0x4,%al
L_003a1e:
        jne L_003a23
L_003a20:
        jmp L_003581
