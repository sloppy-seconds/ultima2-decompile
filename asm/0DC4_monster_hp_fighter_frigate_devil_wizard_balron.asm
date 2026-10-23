# monster_hp_fighter_frigate_devil_wizard_balron — five spawn arms, type + HP each
# name-evidence: each arm stores a type immediate to [DI+0x197], stamps it into the
#           map cell, then stores an HP immediate to [DI+0x177] (monster HP, proven by
#           asm/2E3D_combat_attack_flow). The five pairs, with the art each type folds
#           to under >>2 and the third-party HP for that art:
#             0xF0 -> 0x80 (128)  art 0x3C Fighter   third-party 128   match
#             0x48 -> 0xA0 (160)  art 0x12 Frigate   third-party 160   match
#             0x38 -> 0xC0 (192)  art 0x0E Devil     third-party 192   match
#             0xF8 -> 0xE0 (224)  art 0x3E Wizard    third-party 224   match
#             0x3C -> 0xFF (255)  art 0x0F Balron    third-party 255   match
#           Balron is `mov $0xff`: the literal byte ceiling, which is why the sources
#           report 255 where the 32-step progression would predict 256. The overworld
#           HP "table" does not exist as data — it is immediates in a compare chain,
#           which is why tools/hp_table_scan.py correctly found nothing.
# provenance: static, 2026-10-22; extracted by tools/monster_hp_dispatch.py
# confidence: high for the fields and values (bytes); creature names remain third-party
# label: kept as sub_0dc4 on purpose — labels are body (CP0)
# GUARD BYTE: [DI+0x1B7] is the terrain tile of the rolled spawn coordinate, stored by
#   asm/0CEE one instruction before the chain runs. Fighter, Devil, Wizard and Balron want
#   0x08 (land); Frigate wants 0x00 (water). The `decb 0x60` at the head of this file is the
#   shared reject tail the arms jump to when the terrain does not match, and it is what makes
#   DS:60 creep instead of march.
# RUNTIME CONFIRMED 2026-10-28, by forcing DS:60 and trapping arm entries as well as by
#   outcome census: Fighter arm entry ran with the chain at 0x10 (AL=00, rejected); Devil
#   appeared with the chain at 0x40; Wizard with the chain at 0x80; the Balron arm entry ran
#   with the chain at 0x00, i.e. no bits set falls through to it. docs/monster-spawn.md 15.4.
# func 0DC4..0E6F  len 00AC B  evidence: seed+reko
# calls: L_000daf, L_000fc4, L_000ff3, L_001012, L_001031
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0dc4:
L_000fc4:
        decb   0x60
L_000fc8:
        jmp L_000daf
L_000fcb:
        jmp L_000ff3
L_000fcd:
        nop
L_000fce:
        jmp L_001012
L_000fd0:
        nop
L_000fd1:
        jmp L_001031
L_000fd3:
        nop
L_000fd4:
        mov    0x1b7(%di),%al
L_000fd8:
        cmp    $0x8,%al
L_000fda:
        je L_000fde
L_000fdc:
        jmp L_000fc4
L_000fde:
        mov    $0xf0,%al
L_000fe0:
        mov    0x6,%bx
L_000fe4:
        mov    %al,(%bx,%si)
L_000fe6:
        mov    %al,0x197(%di)
L_000fea:
        mov    $0x80,%al
L_000fec:
        mov    %al,0x177(%di)
L_000ff0:
        jmp L_000daf
L_000ff3:
        mov    0x1b7(%di),%al
L_000ff7:
        cmp    $0x0,%al
L_000ff9:
        je L_000ffd
L_000ffb:
        jmp L_000fc4
L_000ffd:
        mov    $0x48,%al
L_000fff:
        mov    0x6,%bx
L_001003:
        mov    %al,(%bx,%si)
L_001005:
        mov    %al,0x197(%di)
L_001009:
        mov    $0xa0,%al
L_00100b:
        mov    %al,0x177(%di)
L_00100f:
        jmp L_000daf
L_001012:
        mov    0x1b7(%di),%al
L_001016:
        cmp    $0x8,%al
L_001018:
        je L_00101c
L_00101a:
        jmp L_000fc4
L_00101c:
        mov    $0x38,%al
L_00101e:
        mov    0x6,%bx
L_001022:
        mov    %al,(%bx,%si)
L_001024:
        mov    %al,0x197(%di)
L_001028:
        mov    $0xc0,%al
L_00102a:
        mov    %al,0x177(%di)
L_00102e:
        jmp L_000daf
L_001031:
        mov    0x1b7(%di),%al
L_001035:
        cmp    $0x8,%al
L_001037:
        je L_00103b
L_001039:
        jmp L_000fc4
L_00103b:
        mov    $0xf8,%al
L_00103d:
        mov    0x6,%bx
L_001041:
        mov    %al,(%bx,%si)
L_001043:
        mov    %al,0x197(%di)
L_001047:
        mov    $0xe0,%al
L_001049:
        mov    %al,0x177(%di)
L_00104d:
        jmp L_000daf
L_001050:
        mov    0x1b7(%di),%al
L_001054:
        cmp    $0x8,%al
L_001056:
        je L_00105b
L_001058:
        jmp L_000fc4
L_00105b:
        mov    $0x3c,%al
L_00105d:
        mov    0x6,%bx
L_001061:
        mov    %al,(%bx,%si)
L_001063:
        mov    %al,0x197(%di)
L_001067:
        mov    $0xff,%al
L_001069:
        mov    %al,0x177(%di)
L_00106d:
        jmp L_000daf
