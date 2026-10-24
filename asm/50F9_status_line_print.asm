# show_hitpoints — status line: hit points
# name-evidence: string 'H.P.='
# func 50F9..51A4  len 00AC B  evidence: seed+call+reko
# MERGED 2026-10-28d from 25 fragments the Phase 2/3 wave cut out of one routine: 5111 5112 5120 5121 5123 5124 5126 5129 513C 513D 514B 514C 514E 514F 5151 5152 5154 5167 5168 5175 5188 5189 5196 51A4. Body lines are concatenated in address order and none was edited; engine/tests/asm_body_guard.py requires the tree's assemblable content to be conserved, and it is.
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
sub_5111:
L_005311:
        .byte 0xb7  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
sub_5112:
L_005312:
        add    %cl,0x521e(%bp,%si)
L_005316:
        add    %cl,-0x5f05(%bp,%di)
L_00531a:
        push   %cx
L_00531b:
        add    %cl,(%bp,%si)
L_00531d:
        .byte 0xc0,0x75,0x03  # forced-kept: gas re-encodes 'shlb   $0xe8,0x3(%di)' differently
sub_5120:
L_005320:
        .byte 0xe8  # forced-kept: stop-trunc call   0x55df
sub_5121:
L_005321:
        .byte 0xbc,0x02  # forced-kept: gas re-encodes 'mov    $0xe802,%sp' differently
sub_5123:
L_005323:
        .byte 0xe8  # forced-kept: stop-trunc call   0x53a5
sub_5124:
L_005324:
        jg L_005326
sub_5126:
L_005326:
        call L_0055d9
sub_5129:
L_005329:
        mov    $0x1e,%al
L_00532b:
        mov    %al,0x2e
L_00532e:
        movb   $0x15,0x2f
L_005333:
        call L_0051df
        db "FOOD=",0x00        # string
sub_513c:
L_00533c:
        .byte 0xb7  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
sub_513d:
L_00533d:
        add    %cl,0x541e(%bp,%si)
L_005341:
        add    %cl,-0x5f05(%bp,%di)
L_005345:
        push   %bx
L_005346:
        add    %cl,(%bp,%si)
L_005348:
        .byte 0xc0,0x75,0x03  # forced-kept: gas re-encodes 'shlb   $0xe8,0x3(%di)' differently
sub_514b:
L_00534b:
        .byte 0xe8  # forced-kept: stop-trunc call   0x55df
sub_514c:
L_00534c:
        xchg   %ax,%cx
L_00534d:
        .byte 0x02  # forced-kept: gas re-encodes 'add    %al,%ch' differently
sub_514e:
L_00534e:
        .byte 0xe8  # forced-kept: stop-trunc call   0x53a5
sub_514f:
L_00534f:
        push   %sp
        db 0x00        # tail-pad
sub_5151:
L_005351:
        .byte 0xe8  # forced-kept: stop-trunc call   0x55d9
sub_5152:
L_005352:
        test   %ax,(%bp,%si)
sub_5154:
L_005354:
        mov    $0x1e,%al
L_005356:
        mov    %al,0x2e
L_005359:
        movb   $0x16,0x2f
L_00535e:
        call L_0051df
        db "EXP.=",0x00        # string
sub_5167:
L_005367:
        .byte 0xa0  # forced-kept: gas re-encodes 'mov    0x56,%al' differently
sub_5168:
L_005368:
        push   %si
L_005369:
        add    %dh,-0x7600(%bx)
L_00536d:
        push   %ds
L_00536e:
        push   %di
L_00536f:
        add    %cl,-0x1705(%bp,%di)
L_005373:
        xor    %al,(%bx,%si)
sub_5175:
L_005375:
        mov    $0x1e,%al
L_005377:
        mov    %al,0x2e
L_00537a:
        movb   $0x17,0x2f
L_00537f:
        call L_0051df
        db "GOLD=",0x00        # string
sub_5188:
L_005388:
        .byte 0xa0  # forced-kept: gas re-encodes 'mov    0x58,%al' differently
sub_5189:
L_005389:
        .byte 0x58  # forced-kept: gas re-encodes 'pop    %ax' differently
L_00538a:
        .byte 0x00,0xb7,0x00,0x8a  # forced-kept: gas re-encodes 'add    %dh,-0x7600(%bx)' differently
L_00538e:
        .byte 0x1e  # forced-kept: gas re-encodes 'push   %ds' differently
L_00538f:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_005390:
        .byte 0x00,0x8b,0xfb,0xe8  # forced-kept: gas re-encodes 'add    %cl,-0x1705(%bp,%di)' differently
L_005394:
        .byte 0x0f,0x00  # forced-kept: gas re-encodes '(bad)' differently
sub_5196:
L_005396:
        mov    $0x1d,%al
L_005398:
        mov    %al,0x31
L_00539b:
        mov    $0x0,%di
L_00539e:
        mov    $0x17,%si
L_0053a1:
        call L_0053eb
sub_51a4:
L_0053a4:
        ret
