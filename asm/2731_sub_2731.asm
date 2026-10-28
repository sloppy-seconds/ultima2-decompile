# sub_2731 — mechanical clean (bulk wave); behavior not yet reviewed
# DECODED 2026-10-29: this is the `0xC0` test. `cmp $0xc0,%al ; jne L_002944` asks whether the
#           tile that asm/2708 just looked up is a time door, and falls through to asm/2735 when
#           it is. `0xC0` is the moongate stamp: observed live as the byte at the gate cell in
#           the stamped grid at DS:1800, at cells that are NOT `0xC0` in the authored mapx, so
#           it is placed at runtime (docs/moongates.md § 1, § 5).
#           WHY THIS WAS MISSED: docs/contract-overworld-walk.md censused `mov $0xc0,%al` —
#           stores — and concluded no code names the byte. A `cmp` is a reader, and nothing
#           looked for one. That refutation also cited mapx03, a castle sector, while every
#           wilderness mapx has zero `0xC0` cells at all.
#           NAME PROPOSED, NOT APPLIED: gate_tile_test. Causal link unproven; see asm/2708 and
#           docs/moongates.md § 6.
# func 2731..2734  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2731:
L_002931:
        cmp    $0xc0,%al
L_002933:
        jne L_002944
