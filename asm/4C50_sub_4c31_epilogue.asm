# sub_4c31_epilogue — the pop/ret that ends asm/4C31's routine. A tiling artifact, not a
#           claim that a routine starts here.
# name-evidence: asm/4C31_sub_4c31.asm loads %es from a CS table, walks %si and %di and loops
#           on %dl (`dec %dl ; jne` at file 0x4E4C), and this is `pop %es ; pop %si ; pop %di ;
#           pop %dx ; ret` — the unwind of exactly those four registers, five bytes, sitting
#           immediately after the loop's back edge. Nothing calls it; it is a tail.
# WHY IT IS STILL ITS OWN FILE: the tree tiles by discovered start and 0x4C50 is a block start
#           the runtime CFG reported, so the row survives in disasm/function-map.tsv. Folding
#           these five lines into asm/4C31 is the tidier cut and is deliberately NOT done here:
#           engine/tests/asm_body_guard.py permits a removed file only when its address
#           reappears as a marked new file, so a merge in the same commit as the correction
#           below would read as content removed. Recorded so the next person tidies it on
#           purpose rather than discovering it by accident.
# body corrected: 2026-10-25 -- evidence: this span was one file containing the name pool as
#           well, and the name pool is data. See asm/4C55_name_pool.asm for the method and the
#           independent confirmation. The bytes are unchanged and tools/assemble_clean.sh is
#           green over the whole binary.
# func 4C50..4C54  len 0005 B  evidence: seed+reko
# provenance: live:airport (+22 other harvests at the time of counting), static
# confidence: high for the five bytes; the routine they end is asm/4C31
# label: the old `plane_landing_site:` is dropped — it named the data block, and the data block
#           was not a landing site either. Labels are body, so this is a marked change.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
L_004e50:
        pop    %es
L_004e51:
        pop    %si
L_004e52:
        pop    %di
L_004e53:
        pop    %dx
L_004e54:
        ret
