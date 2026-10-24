# show_hitpoints — status line: hit points
# name-evidence: string 'H.P.='
# func 50F9..5110  len 0018 B  evidence: seed+call+reko
# strings: "H.P.="
# calls: L_0051df (str_out)
# provenance: live:airport (+50 other harvests), static
#           entry executed in 51 of 60 harvests; derived by tools/provenance_from_traces.py
#           confidence: low (bytes proven by check_func.py)
# REAL FUNCTION SPAN: runtime 50F9..51A4 — **25 fragments, one `ret` at asm/51A4**, the worst
#           split in the tree and now confirmed as one routine by `tools/fragment_splits.py`
#           on 2026-10-28d. It is the status-line printer: each field is a basic block that
#           positions the cursor (DS:2E/DS:2F), calls `str_out` with the label, then emits the
#           value. Four labelled fields on record — `H.P.=`, `FOOD=`, `EXP.=`, `GOLD=` — and
#           the run ends at asm/51A4's lone `ret`.
#           Why it fragmented so badly: most of the interior bytes are `reko`-only rows with no
#           seed, and the clean wave rendered them as forced-keep `.byte` lines or as nonsense
#           (`add %cl,0x521e(%bp,%si)` is not a real addressing mode here, it is a mis-decoded
#           immediate). So the fragment boundaries are artefacts of a decode failure, not of
#           control flow — which is the case to look for before proposing any merge here.
#           Do not merge from the TSV alone: read the span, and expect `asm_body_guard` to
#           object if the byte-for-byte content is not conserved.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
show_hitpoints:
L_0052f9:
        mov    $0x28,%al
L_0052fb:
        mov    %al,0x31
L_0052fe:
        movb   $0x1e,0x2e
L_005303:
        mov    $0x14,%al
L_005305:
        mov    %al,0x2f
L_005308:
        call L_0051df
        db "H.P.=",0x00        # string
