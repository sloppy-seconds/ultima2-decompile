# Byte-check report (CP6)

Sample: 44 functions = all 26 jump-table handlers + 18 stratified (seed=20261019).

Method: every integer literal and DS-relative operand asserted by the decompiler C must appear as a little-endian byte pattern (1-4 B) inside the claimed range of `original/ultimaii.exe`. Ghidra ranges = claimed body size; failed stubs claim nothing (`no-claims`); Reko ranges = the procedure's own `l0800_` label extent from `ultimaii.dis` (+6 B last-instruction slack). Extraction strips comments, struct-layout fields, type tags, internal ids, and char literals - none of these are instruction claims. Literals <=2 skipped (implicit). Tool: `tools/bytecheck.py`.

| entry | src | handler | ghidra | g-size | g-lits | g-missing | reko | r-span | r-lits | r-missing | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 080D | stratified |  | ok | 0x2c | 293 | 0x3,0x4,0x5,0x6,0x7,0x8,0x9,0xC,0xF,0x10,0x12,0x15,0x16,0x18,0x19,0x1A,0x1F,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x30,0x34,0x38,0x3C,0x3E,0x3F,0x40,0x41,0x42,0x45,0x48,0x49,0x4A,0x4B,0x4C,0x4E,0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5D,0x60,0x61,0x62,0x66,0x70,0x77,0x7F,0x80,0x8D,0x8F,0x99,0xBF,0xE0,0xF0,0xFC,0xFE,0xFF,0x100,0x137,0x157,0x177,0x197,0x1B7,0x1D7,0x1F7,0x217,0x26E,0x26F,0x270,0x271,0x371,0x398,0x63A,0x881,0x88D,0x890,0x893,0x896,0x8AF,0x8CE,0x8D1,0x8E6,0x8EA,0x8ED,0x8F0,0x8F3,0x8F6,0x8F9,0x907,0x948,0x95C,0x968,0x983,0x98F,0x9AA,0x9B5,0x9D0,0x9DB,0xA05,0xA80,0xAAA,0xAB6,0xAC0,0xAC7,0xADE,0xAE8,0xAF2,0xAFC,0xB07,0xB62,0xB65,0xBB2,0xBBC,0xBC9,0xBCC,0xBCF,0xBDB,0xC00,0xC01,0xC1F,0xC33,0xC82,0xC85,0xC8C,0xC8F,0xCB9,0xCD2,0xCEE,0xEFE,0x1055,0x1066,0x106D,0x107F,0x10A0,0x10A7,0x10AA,0x10BC,0x10BF,0x1124,0x1163,0x1197,0x11E5,0x121F,0x1230,0x1257,0x127E,0x129C,0x129F,0x12B7,0x12D0,0x12D5,0x12D8,0x130C,0x1357,0x135A,0x136B,0x136E,0x1371,0x1374,0x13B5,0x13DD,0x1414,0x1434,0x178E,0x17FF,0x214D,0x2150,0x2166,0x2169,0x2186,0x2189,0x2233,0x225A,0x2278,0x2680,0x27CB,0x27D9,0x27F5,0x280D,0x2810,0x282A,0x2865,0x2877,0x28A8,0x28B5,0x28BD,0x28D6,0x28D9,0x28DC,0x28E9,0x2916,0x2948,0x297B,0x298D,0x2A05,0x2A3E,0x2A4D,0x2A5C,0x2A6B,0x2A7A,0x2A89,0x2A98,0x2AA7,0x2AB9,0x2AC8,0x2ADA,0x2AE9,0x2AF8,0x2B07,0x2B19,0x2B28,0x2B37,0x2B46,0x2B92,0x2BB0,0x2BC1,0x2BC4,0x2BC7,0x2BDA,0x2BE9,0x2BEC,0x2BEF,0x2BFB,0x2E0C,0x2E1A,0x2E36,0x2E81,0x2E91,0x2E99,0x2E9C,0x2E9F,0x2EF4,0x2F05,0x2F17,0x2F21,0x2F39,0x2F44,0x2F4C,0x2F67,0x2F72,0x2F82,0x2F93,0x2FAD,0x4805,0x4CFF,0x4D00,0x4FFA,0x4FFB,0x5DEC,0x74FE,0xE7FF,0xEB00,0xFF3F,0xFFFF,0x10BA6,0x1144C,0x11451 | def | 0x6 | 1 | 0x78 | mismatch |
| 0940 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 1 | - | verified |
| 0A5F | stratified |  | failed | 0x0 | 0 | - | def | 0x9b7 | 32 | 0x1757 | mismatch |
| 0AB6 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 1 | - | verified |
| 0BDB | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 1 | - | verified |
| 0D21 | stratified |  | failed | 0x0 | 0 | - | def | 0x140 | 10 | 0x7 | mismatch |
| 20EB | stratified |  | ok | 0x36 | 7 | 0x9,0xF,0x99 | def | 0x6 | 0 | - | mismatch |
| 21BD | stratified |  | ok | 0x8 | 9 | 0x4,0x14,0x23,0x24,0x4A,0x70,0xFF | def | 0x6 | 2 | - | mismatch |
| 2233 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 7 | 0x23,0x24,0x27,0x28,0x137,0x157 | mismatch |
| 2305 | stratified |  | ok | 0x3b | 8 | 0x3,0x8,0xCF | def | 0x6 | 4 | 0x28,0x800,0x1000 | mismatch |
| 2495 | stratified |  | failed | 0x0 | 0 | - | def | 0x1f | 1 | - | verified |
| 2599 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 1 | 0x19 | mismatch |
| 26C3 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 2B8F | handler | handler=A | failed | 0x0 | 0 | - | def | 0x6 | 1 | 0x2D | mismatch |
| 2F6F | handler | handler=B | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 310B | handler | handler=C | failed | 0x0 | 0 | - | def | 0x6 | 5 | 0x28,0x1CE8,0x4000,0xBA00,0xEB00 | mismatch |
| 334D | handler | handler=D | failed | 0x0 | 0 | - | def | 0x37 | 6 | 0x8 | mismatch |
| 3389 | handler | handler=E | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 35C1 | handler | handler=F | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 363B | handler | handler=G | failed | 0x0 | 0 | - | def | 0x125 | 21 | 0x10,0x1700,0x494C | mismatch |
| 3782 | handler | handler=H | failed | 0x0 | 0 | - | def | 0x6 | 1 | - | verified |
| 3794 | handler | handler=I | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 37DC | handler | handler=J | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 37F1 | handler | handler=K | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 38B0 | handler | handler=L | failed | 0x0 | 0 | - | def | 0x29d | 37 | - | verified |
| 3B92 | handler | handler=M | failed | 0x0 | 0 | - | def | 0x22 | 1 | 0x24 | mismatch |
| 3BCE | handler | handler=N | failed | 0x0 | 0 | - | def | 0x6 | 2 | 0x49,0xE3 | mismatch |
| 3C2E | handler | handler=O | failed | 0x0 | 0 | - | def | 0x162 | 20 | - | verified |
| 3DBC | handler | handler=P | ok | 0x7 | 1 | 0x3 | def | 0x6 | 0 | - | mismatch |
| 3DC7 | handler | handler=Q | failed | 0x0 | 0 | - | def | 0x6 | 3 | 0x41,0x52,0x800 | mismatch |
| 3E50 | handler | handler=R | failed | 0x0 | 0 | - | def | 0x6 | 8 | 0xD,0x20,0x2D,0x2D39,0x494C,0x5247,0x532D | mismatch |
| 3F25 | handler | handler=S | failed | 0x0 | 0 | - | def | 0x6 | 2 | 0x49,0xE800 | mismatch |
| 3F36 | stratified |  | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 4050 | handler | handler=T | failed | 0x0 | 0 | - | def | 0x6 | 1 | 0xE800 | mismatch |
| 42F1 | handler | handler=U | failed | 0x0 | 0 | - | def | 0x6 | 2 | 0x49,0xE800 | mismatch |
| 437E | handler | handler=V | ok | 0x18 | 29 | 0x3,0x4,0x6,0x8,0x9,0xF,0x10,0x19,0x1A,0x23,0x24,0x4A,0x60,0x70,0x77,0x99,0xF0,0x2A5C,0x2AF8,0x2B37,0x43CF,0xFFFE | def | 0x72 | 12 | 0x10 | mismatch |
| 43F3 | handler | handler=W | failed | 0x0 | 0 | - | def | 0xd3 | 17 | 0x800 | mismatch |
| 44D4 | handler | handler=X | failed | 0x0 | 0 | - | def | 0x55 | 9 | - | verified |
| 4542 | handler | handler=Y | failed | 0x0 | 0 | - | def | 0x6 | 1 | 0x48 | mismatch |
| 4568 | handler | handler=Z | failed | 0x0 | 0 | - | def | 0x6 | 0 | - | no-claims |
| 4864 | stratified |  | absent | 0x0 | 0 | - | def | 0x6 | 1 | - | verified |
| 4F69 | stratified |  | ok | 0x1 | 16 | 0x6,0x8,0x16,0x60,0x74,0x7B,0xDF,0xFF,0x200,0x54D,0x554,0x3A01,0x4F09,0x4F0A,0x7300,0x7400 | def | 0x6 | 0 | - | mismatch |
| 5270 | stratified |  | ok | 0x8 | 0 | - | def | 0x6 | 2 | - | verified |
| 5AFF | stratified |  | ok | 0x34 | 28 | 0x3,0x5,0x8,0x10,0x13,0x14,0x15,0x16,0x17,0x18,0x2E,0x40,0x7F,0x80,0x272,0x2CB,0x2DE,0x2DF,0x2E0,0x2F3,0x372,0x54E | def | 0x6 | 0 | - | mismatch |

Totals: 10 verified, 25 mismatch, 9 no-claims of 44.

## Flag detail (context line in the decompiler C; pattern location)

### 080D (stratified)

- ghidra 0x3: elsewhere-in-file | `*(byte *)0x1 = *(char *)0x1 + *(char *)0x3 & 0x3f;`
- ghidra 0x4: elsewhere-in-file
- ghidra 0x5: elsewhere-in-file
- ghidra 0x6: elsewhere-in-file | `*(byte *)(*(int *)0x6 + (int)unaff_SI) = 0x50;`
- ghidra 0x7: elsewhere-in-file
- ghidra 0x8: elsewhere-in-file | `*(byte *)(*(int *)0x8 + (int)puVar536) = *(byte *)(*(int *)0x8 + (int)puVar536) & 0xf0;`
- ghidra 0x9: elsewhere-in-file
- ghidra 0xC: elsewhere-in-file | `if (bVar11 != 0xc) {`
- ghidra 0xF: elsewhere-in-file | `in_AF = 9 < (bVar8 & 0xf) | in_AF;`
- ghidra 0x10: elsewhere-in-file | `out((byte)*puVar3,(int)((ulong)uVar550 >> 0x10));`
- ghidra 0x12: elsewhere-in-file | `*(undefined1 *)0x12 = 0xff;`
- ghidra 0x15: elsewhere-in-file | `((byte *)((int)puVar22 + (int)unaff_SI))[0x15] =`
- ghidra 0x16: elsewhere-in-file | `((byte *)((int)puVar22 + (int)unaff_SI))[0x16] =`
- ghidra 0x18: elsewhere-in-file | `((byte *)((int)puVar22 + (int)unaff_SI))[0x18] =`
- ghidra 0x19: elsewhere-in-file | `*(char *)0x19 = -*(char *)0x19;`
- ghidra 0x1A: elsewhere-in-file | `*(char *)0x1a = -*(char *)0x1a;`
- ghidra 0x1F: elsewhere-in-file | `*(undefined1 *)0x1f = (char)puVar536;`
- ghidra 0x20: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x177) = 0x20;`
- ghidra 0x21: elsewhere-in-file | `*(undefined1 *)0x21 = 0;`
- ghidra 0x22: elsewhere-in-file | `*(undefined1 *)0x22 = 0xc0;`
- ghidra 0x23: elsewhere-in-file | `*(undefined1 *)0x23 = *(undefined1 *)0x6a;`
- ghidra 0x24: elsewhere-in-file | `*(undefined1 *)0x24 = *(undefined1 *)0x6b;`
- ghidra 0x25: elsewhere-in-file | `if (bVar11 < *(byte *)0x25) {`
- ghidra 0x26: elsewhere-in-file | `*(undefined1 *)0x26 = 0;`
- ghidra 0x27: elsewhere-in-file | `*(undefined1 *)0x27 = 0x14;`
- ghidra 0x28: elsewhere-in-file | `*(undefined1 *)0x28 = *(undefined1 *)0x24;`
- ghidra 0x29: elsewhere-in-file | `*(undefined1 *)0x29 = (char)puVar536;`
- ghidra 0x2A: elsewhere-in-file | `*(byte *)(puVar540 + 0x2a) = (byte)puVar540[0x2a] & extraout_DL_04 + 1U;`
- ghidra 0x2B: elsewhere-in-file | `*(byte *)(puVar22 + 0x2b) = (byte)puVar22[0x2b] & bVar11;`
- ghidra 0x2C: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x2c;`
- ghidra 0x30: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x30;`
- ghidra 0x34: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x34;`
- ghidra 0x38: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x38;`
- ghidra 0x3C: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x3c;`
- ghidra 0x3E: elsewhere-in-file | `if (0x3e < bVar11) break;`
- ghidra 0x3F: elsewhere-in-file | `bVar542 = (char)(bVar11 - 0x3f) <  ;`
- ghidra 0x40: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x177) = 0x40;`
- ghidra 0x41: elsewhere-in-file | `if ((bVar11 < 0x41) || (0x5a < bVar11)) {`
- ghidra 0x42: elsewhere-in-file | `case 0x42:`
- ghidra 0x45: elsewhere-in-file | `*(byte *)((int)unaff_SI + 0x45) = *(byte *)((int)unaff_SI + 0x45) & bVar11;`
- ghidra 0x48: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0x48;`
- ghidra 0x49: elsewhere-in-file | `(puVar65 + (int)unaff_SI)[0x49] =`
- ghidra 0x4A: elsewhere-in-file | `while (puVar24 = (undefined1 *)0x100, puVar535 = unaff_SI, *(byte *)0x4a < 4) {`
- ghidra 0x4B: elsewhere-in-file | `(byte)(*(char *)0x61 *   + *(char *)0x4b + CARRY1(bVar11,bVar11)) >> 2;`
- ghidra 0x4C: elsewhere-in-file | `if ((byte)((uVar17 & 0xff) >> 1) < *(byte *)0x4c) {`
- ghidra 0x4E: elsewhere-in-file | `(puVar531 + (int)puVar535)[0x4e] = (puVar531 + (int)puVar535)[0x4e] & extraout_DL;`
- ghidra 0x4F: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x4f) = *(byte *)((int)puVar536 + 0x4f) & (byte)in_CX;`
- ghidra 0x50: elsewhere-in-file | `*(byte *)(*(int *)0x6 + (int)unaff_SI) = 0x50;`
- ghidra 0x51: elsewhere-in-file | `*(undefined1 *)0x51 = 0;`
- ghidra 0x52: elsewhere-in-file | `*(undefined1 *)0x52 = 0;`
- ghidra 0x53: elsewhere-in-file | `bVar11 = *(byte *)0x53;`
- ghidra 0x54: elsewhere-in-file | `bVar10 = *(byte *)0x54;`
- ghidra 0x55: elsewhere-in-file | `bVar11 = *(byte *)0x55;`
- ghidra 0x56: elsewhere-in-file | `*(undefined1 *)0x56 = 0;`
- ghidra 0x57: elsewhere-in-file | `*(undefined1 *)0x57 = 0;`
- ghidra 0x58: elsewhere-in-file | `*(undefined1 *)0x58 = 0;`
- ghidra 0x59: elsewhere-in-file | `*(undefined1 *)0x59 = 0;`
- ghidra 0x5D: elsewhere-in-file | `*(undefined1 *)0x5d = (char)uVar16;`
- ghidra 0x60: elsewhere-in-file | `*(char *)0x55 = bVar8 + in_AF * -6 + (0x99 < bVar8 || (bVar11 < 10 || bVar542)) * -0x60;`
- ghidra 0x61: elsewhere-in-file | `bVar11 = *(char *)0x61 *  ;`
- ghidra 0x62: elsewhere-in-file | `if ((-1 < (char)bVar11) && (*(byte *)0x62 <= (bVar11 & 7))) {`
- ghidra 0x66: elsewhere-in-file | `if (*(char *)0x66 ==  ) goto FUN_1000_0c62;`
- ghidra 0x70: elsewhere-in-file | `else if (bVar11 == 0x70) {`
- ghidra 0x77: elsewhere-in-file | `*(char *)0x22 = (bVar11 & *(byte *)0x22 & 0x77) + 1;`
- ghidra 0x7F: elsewhere-in-file | `if ((bVar542) || ((bVar11 != 0xff && ((bVar11 & 0x7f) != 0)))) goto  x0001122d;`
- ghidra 0x80: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x177) = 0x80;`
- ghidra 0x8D: elsewhere-in-file | `in_CX = (byte *)((int)puVar536 + 0x8d);`
- ghidra 0x8F: elsewhere-in-file | `if ((uVar551 & 0x8f) != 0) {`
- ghidra 0x99: elsewhere-in-file | `*(char *)0x55 = bVar8 + in_AF * -6 + (0x99 < bVar8 || (bVar11 < 10 || bVar542)) * -0x60;`
- ghidra 0xBF: elsewhere-in-file | `bVar10 = (bVar11 + 0xbf) *  ;`
- ghidra 0xE0: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x177) = 0xe0;`
- ghidra 0xF0: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0xf0;`
- ghidra 0xFC: elsewhere-in-file | `*(byte *)((int)puVar22 + (int)unaff_SI) = 0xfc;`
- ghidra 0xFE: elsewhere-in-file | `puVar25 = (undefined1 *)0xfe;`
- ghidra 0xFF: elsewhere-in-file | `puVar22 = (uint *)0xff;`
- ghidra 0x100: elsewhere-in-file | `while (puVar24 = (undefined1 *)0x100, puVar535 = unaff_SI, *(byte *)0x4a < 4) {`
- ghidra 0x137: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x137) = bVar11;`
- ghidra 0x157: elsewhere-in-file | `*(byte *)(*(byte *)0x1f + 0x157) = bVar11 & 0x3f;`
- ghidra 0x177: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x177) = 0xe0;`
- ghidra 0x197: elsewhere-in-file | `if (*(byte *)((int)puVar536 + 0x197) == 0) {`
- ghidra 0x1B7: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x1b7) = bVar11;`
- ghidra 0x1D7: elsewhere-in-file | `bVar11 = *(byte *)((int)puVar536 + 0x1d7);`
- ghidra 0x1F7: elsewhere-in-file | `*(undefined1 *)0x19 = *(undefined1 *)(bVar11 + 0x1f7);`
- ghidra 0x217: elsewhere-in-file | `*(undefined1 *)0x1a = *(undefined1 *)(bVar11 + 0x217);`
- ghidra 0x26E: elsewhere-in-file | `if (cVar9 == *(char *)0x26e) goto FUN_1000_0955;`
- ghidra 0x26F: elsewhere-in-file | `if (cVar9 == *(char *)0x26f) {`
- ghidra 0x270: elsewhere-in-file | `if (cVar9 != *(char *)0x270) {`
- ghidra 0x271: elsewhere-in-file | `*(byte *)((int)puVar536 + 0x271) = 0xff;`
- ghidra 0x371: absent-from-file | `*(byte *)((int)puVar536 + 0x371) = 0xff;`
- ghidra 0x398: absent-from-file | `puVar22 = (uint *)puVar536[0x398];`
- ghidra 0x63A: elsewhere-in-file | `puVar531 = (undefined1 *)0x63a;`
- ghidra 0x881: absent-from-file | `*(undefined2 *)0xfe = 0x881;`
- ghidra 0x88D: absent-from-file | `*(undefined2 *)(*(int *)(puVar25 + 1) + -2) = 0x88d;`
- ghidra 0x890: elsewhere-in-file | `*(undefined2 *)(puVar26 + -2) = 0x890;`
- ghidra 0x893: absent-from-file | `*(undefined2 *)(puVar27 + -2) = 0x893;`
- ghidra 0x896: absent-from-file | `*(undefined2 *)(puVar28 + -2) = 0x896;`
- ghidra 0x8AF: absent-from-file | `*(undefined2 *)((int)puVar189 + -2) = 0x8af;`
- ghidra 0x8CE: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x8ce;`
- ghidra 0x8D1: absent-from-file | `*(undefined2 *)(puVar30 + -2) = 0x8d1;`
- ghidra 0x8E6: absent-from-file | `*puVar31 = 0x8e6;`
- ghidra 0x8EA: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x8ea;`
- ghidra 0x8ED: absent-from-file | `*(undefined2 *)(puVar32 + -2) = 0x8ed;`
- ghidra 0x8F0: absent-from-file | `*(undefined2 *)(puVar33 + -2) = 0x8f0;`
- ghidra 0x8F3: absent-from-file | `*(undefined2 *)(puVar34 + -2) = 0x8f3;`
- ghidra 0x8F6: absent-from-file | `*(undefined2 *)(puVar35 + -2) = 0x8f6;`
- ghidra 0x8F9: absent-from-file | `*(undefined2 *)(puVar36 + -2) = 0x8f9;`
- ghidra 0x907: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x907;`
- ghidra 0x948: elsewhere-in-file | `*(undefined2 *)(puVar24 + -2) = 0x948;`
- ghidra 0x95C: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x95c;`
- ghidra 0x968: absent-from-file | `*(undefined2 *)(puVar39 + -6) = 0x968;`
- ghidra 0x983: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x983;`
- ghidra 0x98F: elsewhere-in-file | `*(undefined2 *)(puVar40 + -8) = 0x98f;`
- ghidra 0x9AA: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x9aa;`
- ghidra 0x9B5: absent-from-file | `*(undefined2 *)(puVar41 + -8) = 0x9b5;`
- ghidra 0x9D0: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x9d0;`
- ghidra 0x9DB: absent-from-file | `*(undefined2 *)(puVar42 + -6) = 0x9db;`
- ghidra 0xA05: elsewhere-in-file | `*(undefined2 *)(puVar43 + -2) = 0xa05;`
- ghidra 0xA80: absent-from-file | `puVar536[-0xa80] = puVar536[-0xa80] & (uint)in_CX;`
- ghidra 0xAAA: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0xaaa;`
- ghidra 0xAB6: absent-from-file | `*(undefined2 *)(puVar46 + -2) = 0xab6;`
- ghidra 0xAC0: absent-from-file | `*puVar48 = 0xac0;`
- ghidra 0xAC7: elsewhere-in-file | `*puVar49 = 0xac7;`
- ghidra 0xADE: absent-from-file | `*puVar50 = 0xade;`
- ghidra 0xAE8: elsewhere-in-file | `*puVar51 = 0xae8;`
- ghidra 0xAF2: absent-from-file | `*puVar52 = 0xaf2;`
- ghidra 0xAFC: absent-from-file | `*puVar53 = 0xafc;`
- ghidra 0xB07: absent-from-file | `*(undefined2 *)(puVar47 + -2) = 0xb07;`
- ghidra 0xB62: absent-from-file | `*puVar54 = 0xb62;`
- ghidra 0xB65: absent-from-file | `*(undefined2 *)(puVar72 + -2) = 0xb65;`
- ghidra 0xBB2: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0xbb2;`
- ghidra 0xBBC: elsewhere-in-file | `*puVar56 = 0xbbc;`
- ghidra 0xBC9: absent-from-file | `*(undefined2 *)(puVar55 + -2) = 0xbc9;`
- ghidra 0xBCC: absent-from-file | `*(undefined2 *)(puVar57 + -2) = 0xbcc;`
- ghidra 0xBCF: absent-from-file | `*(undefined2 *)(puVar58 + -2) = 0xbcf;`
- ghidra 0xBDB: absent-from-file | `*puVar59 = 0xbdb;`
- ghidra 0xC00: elsewhere-in-file | `puVar535[-0xc00] = puVar535[-0xc00] & (uint)in_CX;`
- ghidra 0xC01: absent-from-file | `puVar535[-0xc01] = puVar535[-0xc01] & uVar17;`
- ghidra 0xC1F: absent-from-file | `*(undefined2 *)(puVar55 + -2) = 0xc1f;`
- ghidra 0xC33: absent-from-file | `*(undefined2 *)(puVar60 + -2) = 0xc33;`
- ghidra 0xC82: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0xc82;`
- ghidra 0xC85: absent-from-file | `*(undefined2 *)(puVar61 + -2) = 0xc85;`
- ghidra 0xC8C: absent-from-file | `*(undefined2 *)(puVar62 + -2) = 0xc8c;`
- ghidra 0xC8F: absent-from-file | `*(undefined2 *)(puVar63 + -2) = 0xc8f;`
- ghidra 0xCB9: absent-from-file | `*puVar66 = 0xcb9;`
- ghidra 0xCD2: absent-from-file | `*puVar67 = 0xcd2;`
- ghidra 0xCEE: absent-from-file | `*puVar68 = 0xcee;`
- ghidra 0xEFE: elsewhere-in-file | `(pbVar21 + (int)unaff_SI)[0xefe] = (pbVar21 + (int)unaff_SI)[0xefe] & (byte)extraout_DX;`
- ghidra 0x1055: absent-from-file | `*puVar69 = 0x1055;`
- ghidra 0x1066: absent-from-file | `*puVar70 = 0x1066;`
- ghidra 0x106D: absent-from-file | `*puVar71 = 0x106d;`
- ghidra 0x107F: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x107f;`
- ghidra 0x10A0: elsewhere-in-file | `*puVar73 = 0x10a0;`
- ghidra 0x10A7: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x10a7;`
- ghidra 0x10AA: absent-from-file | `*(undefined2 *)(puVar74 + -2) = 0x10aa;`
- ghidra 0x10BC: absent-from-file | `*(undefined2 *)(puVar75 + -2) = 0x10bc;`
- ghidra 0x10BF: elsewhere-in-file | `*(undefined2 *)(puVar76 + -2) = 0x10bf;`
- ghidra 0x1124: absent-from-file | `*puVar77 = 0x1124;`
- ghidra 0x1163: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x1163;`
- ghidra 0x1197: absent-from-file | `*puVar79 = 0x1197;`
- ghidra 0x11E5: absent-from-file | `*puVar80 = 0x11e5;`
- ghidra 0x121F: elsewhere-in-file | `*puVar81 = 0x121f;`
- ghidra 0x1230: elsewhere-in-file | `*puVar82 = 0x1230;`
- ghidra 0x1257: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x1257;`
- ghidra 0x127E: absent-from-file | `*(undefined2 *)(puVar83 + -2) = 0x127e;`
- ghidra 0x129C: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x129c;`
- ghidra 0x129F: absent-from-file | `*(undefined2 *)(puVar84 + -2) = 0x129f;`
- ghidra 0x12B7: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x12b7;`
- ghidra 0x12D0: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x12d0;`
- ghidra 0x12D5: absent-from-file | `*(undefined2 *)(puVar87 + -2) = 0x12d5;`
- ghidra 0x12D8: elsewhere-in-file | `*(undefined2 *)(puVar88 + -2) = 0x12d8;`
- ghidra 0x130C: absent-from-file | `*puVar89 = 0x130c;`
- ghidra 0x1357: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x1357;`
- ghidra 0x135A: absent-from-file | `*(undefined2 *)(puVar90 + -2) = 0x135a;`
- ghidra 0x136B: elsewhere-in-file | `*(undefined2 *)(puVar78 + -2) = 0x136b;`
- ghidra 0x136E: absent-from-file | `*(undefined2 *)(puVar91 + -2) = 0x136e;`
- ghidra 0x1371: absent-from-file | `*(undefined2 *)(puVar92 + -2) = 0x1371;`
- ghidra 0x1374: elsewhere-in-file | `*(undefined2 *)(puVar93 + -2) = 0x1374;`
- ghidra 0x13B5: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x13b5;`
- ghidra 0x13DD: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x13dd;`
- ghidra 0x1414: absent-from-file | `*(undefined2 *)(puVar78 + -2) = 0x1414;`
- ghidra 0x1434: absent-from-file | `*(undefined2 *)((int)piVar96 + -9) = 0x1434;`
- ghidra 0x178E: absent-from-file | `puVar87 = puVar86 + 0x178e;`
- ghidra 0x17FF: absent-from-file | `*(uint *)((int)puVar540 + -0x17ff) = *(uint *)((int)puVar540 + -0x17ff) & (uint)(in_CX + 2`
- ghidra 0x214D: elsewhere-in-file | `*(undefined2 *)(puVar72 + -2) = 0x214d;`
- ghidra 0x2150: elsewhere-in-file | `*(undefined2 *)(puVar195 + -2) = 0x2150;`
- ghidra 0x2166: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x2166;`
- ghidra 0x2169: absent-from-file | `*(undefined2 *)(puVar196 + -2) = 0x2169;`
- ghidra 0x2186: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x2186;`
- ghidra 0x2189: absent-from-file | `*(undefined2 *)(puVar197 + -2) = 0x2189;`
- ghidra 0x2233: absent-from-file | `*(undefined2 *)(puVar65 + -2) = 0x2233;`
- ghidra 0x225A: absent-from-file | `*(undefined2 *)(puVar198 + -2) = 0x225a;`
- ghidra 0x2278: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2278;`
- ghidra 0x2680: absent-from-file | `*(byte *)(puVar22 + -0x2680) = (byte)puVar22[-0x2680] + 1;`
- ghidra 0x27CB: absent-from-file | `*(undefined2 *)0xfe = 0x27cb;`
- ghidra 0x27D9: absent-from-file | `*(undefined2 *)((int)puVar205 + -2) = 0x27d9;`
- ghidra 0x27F5: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x27f5;`
- ghidra 0x280D: absent-from-file | `*(undefined2 *)(puVar206 + -1) = 0x280d;`
- ghidra 0x2810: absent-from-file | `*(undefined2 *)(puVar207 + -2) = 0x2810;`
- ghidra 0x282A: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x282a;`
- ghidra 0x2865: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2865;`
- ghidra 0x2877: absent-from-file | `*(undefined2 *)(puVar209 + -3) = 0x2877;`
- ghidra 0x28A8: absent-from-file | `*(undefined2 *)(puVar209 + -3) = 0x28a8;`
- ghidra 0x28B5: absent-from-file | `*(undefined2 *)((int)puVar530 + -2) = 0x28b5;`
- ghidra 0x28BD: absent-from-file | `*(undefined2 *)(puVar212 + -2) = 0x28bd;`
- ghidra 0x28D6: absent-from-file | `*(undefined2 *)(puVar213 + -2) = 0x28d6;`
- ghidra 0x28D9: absent-from-file | `*(undefined2 *)(puVar214 + -2) = 0x28d9;`
- ghidra 0x28DC: absent-from-file | `*(undefined2 *)(puVar215 + -2) = 0x28dc;`
- ghidra 0x28E9: elsewhere-in-file | `*(undefined2 *)(puVar216 + -2) = 0x28e9;`
- ghidra 0x2916: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2916;`
- ghidra 0x2948: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2948;`
- ghidra 0x297B: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x297b;`
- ghidra 0x298D: absent-from-file | `*(undefined2 *)(puVar220 + -10) = 0x298d;`
- ghidra 0x2A05: absent-from-file | `*puVar225 = 0x2a05;`
- ghidra 0x2A3E: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2a3e;`
- ghidra 0x2A4D: absent-from-file | `*(undefined2 *)(puVar226 + -2) = 0x2a4d;`
- ghidra 0x2A5C: absent-from-file | `*(undefined2 *)(puVar227 + -2) = 0x2a5c;`
- ghidra 0x2A6B: absent-from-file | `*(undefined2 *)(puVar228 + -2) = 0x2a6b;`
- ghidra 0x2A7A: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2a7a;`
- ghidra 0x2A89: absent-from-file | `*(undefined2 *)(puVar229 + -2) = 0x2a89;`
- ghidra 0x2A98: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2a98;`
- ghidra 0x2AA7: absent-from-file | `*(undefined2 *)(puVar230 + -2) = 0x2aa7;`
- ghidra 0x2AB9: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2ab9;`
- ghidra 0x2AC8: absent-from-file | `*(undefined2 *)(puVar231 + -2) = 0x2ac8;`
- ghidra 0x2ADA: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2ada;`
- ghidra 0x2AE9: elsewhere-in-file | `*(undefined2 *)(puVar232 + -2) = 0x2ae9;`
- ghidra 0x2AF8: absent-from-file
- ghidra 0x2B07: absent-from-file | `*(undefined2 *)(puVar234 + -2) = 0x2b07;`
- ghidra 0x2B19: absent-from-file | `*(undefined2 *)(puVar224 + -2) = 0x2b19;`
- ghidra 0x2B28: absent-from-file | `*(undefined2 *)(puVar235 + -2) = 0x2b28;`
- ghidra 0x2B37: absent-from-file | `*(undefined2 *)(puVar236 + -2) = 0x2b37;`
- ghidra 0x2B46: absent-from-file | `*(undefined2 *)(puVar237 + -2) = 0x2b46;`
- ghidra 0x2B92: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2b92;`
- ghidra 0x2BB0: absent-from-file | `*(undefined2 *)(puVar238 + -6) = 0x2bb0;`
- ghidra 0x2BC1: absent-from-file | `*(undefined2 *)(puVar238 + -6) = 0x2bc1;`
- ghidra 0x2BC4: absent-from-file | `*(undefined2 *)(puVar240 + -2) = 0x2bc4;`
- ghidra 0x2BC7: absent-from-file | `*(undefined2 *)(puVar241 + -2) = 0x2bc7;`
- ghidra 0x2BDA: elsewhere-in-file | `*puVar242 = 0x2bda;`
- ghidra 0x2BE9: elsewhere-in-file | `*(undefined2 *)(puVar320 + -2) = 0x2be9;`
- ghidra 0x2BEC: absent-from-file | `*(undefined2 *)(puVar243 + -2) = 0x2bec;`
- ghidra 0x2BEF: absent-from-file | `*(undefined2 *)(puVar244 + -2) = 0x2bef;`
- ghidra 0x2BFB: absent-from-file | `*(undefined2 *)(puVar245 + -4) = 0x2bfb;`
- ghidra 0x2E0C: absent-from-file | `*(undefined2 *)(puVar320 + -2) = 0x2e0c;`
- ghidra 0x2E1A: absent-from-file | `*(undefined2 *)(puVar238 + -6) = 0x2e1a;`
- ghidra 0x2E36: absent-from-file | `*(undefined2 *)(puVar262 + -2) = 0x2e36;`
- ghidra 0x2E81: absent-from-file | `*puVar264 = 0x2e81;`
- ghidra 0x2E91: absent-from-file | `*(undefined2 *)(puVar263 + -2) = 0x2e91;`
- ghidra 0x2E99: absent-from-file | `*(undefined2 *)(puVar265 + -4) = 0x2e99;`
- ghidra 0x2E9C: absent-from-file | `*(undefined2 *)(puVar266 + -2) = 0x2e9c;`
- ghidra 0x2E9F: absent-from-file | `*(undefined2 *)(puVar267 + -2) = 0x2e9f;`
- ghidra 0x2EF4: absent-from-file | `*(undefined2 *)((int)puVar530 + -2) = 0x2ef4;`
- ghidra 0x2F05: elsewhere-in-file | `*(undefined2 *)(puVar268 + -2) = 0x2f05;`
- ghidra 0x2F17: absent-from-file | `*(undefined2 *)(puVar269 + -3) = 0x2f17;`
- ghidra 0x2F21: elsewhere-in-file | `*(undefined2 *)(puVar270 + -2) = 0x2f21;`
- ghidra 0x2F39: absent-from-file | `*(undefined2 *)(puVar271 + -2) = 0x2f39;`
- ghidra 0x2F44: absent-from-file | `puVar272[-1] = 0x2f44;`
- ghidra 0x2F4C: absent-from-file | `*(undefined2 *)((int)puVar273 + -2) = 0x2f4c;`
- ghidra 0x2F67: absent-from-file | `*(undefined2 *)(puVar263 + -2) = 0x2f67;`
- ghidra 0x2F72: absent-from-file | `*(undefined2 *)(puVar24 + -2) = 0x2f72;`
- ghidra 0x2F82: absent-from-file | `*(undefined2 *)(puVar275 + -3) = 0x2f82;`
- ghidra 0x2F93: absent-from-file | `*(undefined2 *)(puVar276 + -2) = 0x2f93;`
- ghidra 0x2FAD: absent-from-file | `*(undefined2 *)(puVar275 + -3) = 0x2fad;`
- ghidra 0x4805: elsewhere-in-file | `*(int *)(puVar65 + (int)puVar536 + -0x4805) = *(int *)(puVar65 + (int)puVar536 + -0x4805) `
- ghidra 0x4CFF: absent-from-file | `*(byte *)((int)puVar22 + -0x4cff) = *(byte *)((int)puVar22 + -0x4cff) + extraout_DH_00;`
- ghidra 0x4D00: elsewhere-in-file | `pbVar21[-0x4d00] = pbVar21[-0x4d00] + (char)((uint)*puVar29 >> 8);`
- ghidra 0x4FFA: absent-from-file | `piVar2 = (int *)(puVar531 + iVar23 + 0x4ffa);`
- ghidra 0x4FFB: elsewhere-in-file | `piVar2 = (int *)(puVar531 + (int)puVar536 + 0x4ffb);`
- ghidra 0x5DEC: absent-from-file | `pbVar4 = (byte *)((int)puVar22 + 1) + (int)unaff_SI + -0x5dec;`
- ghidra 0x74FE: absent-from-file | `(puVar65 + (int)puVar536)[-0x74fe] = (puVar65 + (int)puVar536)[-0x74fe] + extraout_DH_00;`
- ghidra 0xE7FF: absent-from-file | `*(uint *)0xe7ff = *(uint *)0xe7ff & (uint)in_CX;`
- ghidra 0xEB00: elsewhere-in-file | `*(uint *)0xeb00 = *(uint *)0xeb00 & (uint)in_CX;`
- ghidra 0xFF3F: elsewhere-in-file | `uVar17 = CONCAT11((char)((uint)uVar16 >> 8),*(undefined1 *)0x19) & 0xff3f;`
- ghidra 0xFFFF: elsewhere-in-file | `puVar536 = (uint *)0xffff;`
- ghidra 0x10BA6: absent-from-file
- ghidra 0x1144C: absent-from-file
- ghidra 0x11451: absent-from-file
- reko 0x78: elsewhere-in-file | `al = __addc<byte, >(al, 0x78, C);`

### 0A5F (stratified)

- reko 0x1757: absent-from-file

### 0D21 (stratified)

- reko 0x7: elsewhere-in-file

### 20EB (stratified)

- ghidra 0x9: elsewhere-in-file
- ghidra 0xF: elsewhere-in-file | `bVar4 = 9 < (bVar2 & 0xf) | in_AF;`
- ghidra 0x99: elsewhere-in-file | `bVar5 = 0x99 < bVar2 || CARRY1(*(byte *)0x2a,*(byte *)0x28);`

### 21BD (stratified)

- ghidra 0x4: elsewhere-in-file
- ghidra 0x14: elsewhere-in-file | `if (((((bVar1 != 0x10) && (bVar1 != 4)) && (bVar1 != 0)) && ((bVar1 < 0x14 || (bVar1 == 0x`
- ghidra 0x23: elsewhere-in-file | `&& ((*(char *)0x4a ==   || ((*(char *)0x23 !=   && (*(char *)0x24 !=  )))))) {`
- ghidra 0x24: elsewhere-in-file | `&& ((*(char *)0x4a ==   || ((*(char *)0x23 !=   && (*(char *)0x24 !=  )))))) {`
- ghidra 0x4A: elsewhere-in-file | `&& ((*(char *)0x4a ==   || ((*(char *)0x23 !=   && (*(char *)0x24 !=  )))))) {`
- ghidra 0x70: elsewhere-in-file | `if (((((bVar1 != 0x10) && (bVar1 != 4)) && (bVar1 != 0)) && ((bVar1 < 0x14 || (bVar1 == 0x`
- ghidra 0xFF: elsewhere-in-file | `return 0xff;`

### 2233 (stratified)

- reko 0x23: elsewhere-in-file
- reko 0x24: elsewhere-in-file
- reko 0x27: elsewhere-in-file
- reko 0x28: elsewhere-in-file
- reko 0x137: elsewhere-in-file
- reko 0x157: elsewhere-in-file

### 2305 (stratified)

- ghidra 0x3: elsewhere-in-file
- ghidra 0x8: elsewhere-in-file
- ghidra 0xCF: elsewhere-in-file | `cRam0001233d = *(char *)0x4a +   + (0xcf < *(byte *)0x49);`
- reko 0x28: elsewhere-in-file | `byte ah = 0x28;`
- reko 0x800: elsewhere-in-file
- reko 0x1000: elsewhere-in-file | `cx = 0x1000;`

### 2599 (stratified)

- reko 0x19: elsewhere-in-file | `al = __subc<byte, >(al, 0x19, C);`

### 2B8F (handler=A)

- reko 0x2D: elsewhere-in-file | `ax = ax - 0x2D;`

### 310B (handler=C)

- reko 0x28: elsewhere-in-file | `byte ah = 0x28;`
- reko 0x1CE8: elsewhere-in-file
- reko 0x4000: elsewhere-in-file | `cx = 0x4000;`
- reko 0xBA00: elsewhere-in-file
- reko 0xEB00: elsewhere-in-file | `ax = ax - 0xEB00;`

### 334D (handler=D)

- reko 0x8: elsewhere-in-file

### 363B (handler=G)

- reko 0x10: elsewhere-in-file | `C = (ds->*(( ) (( ) bx + 1000) + si) & 0x01 << 0x10 - cl) != 0x00;`
- reko 0x1700: elsewhere-in-file | `SZP = cond(ax & ~0x1700);`
- reko 0x494C: elsewhere-in-file | `ax -= 0x494C;`

### 3B92 (handler=M)

- reko 0x24: elsewhere-in-file | `al = __addc<byte, >(al, 0x24, C);`

### 3BCE (handler=N)

- reko 0x49: elsewhere-in-file
- reko 0xE3: elsewhere-in-file

### 3DBC (handler=P)

- ghidra 0x3: elsewhere-in-file

### 3DC7 (handler=Q)

- reko 0x41: elsewhere-in-file
- reko 0x52: elsewhere-in-file
- reko 0x800: elsewhere-in-file

### 3E50 (handler=R)

- reko 0xD: elsewhere-in-file
- reko 0x20: elsewhere-in-file | `al = al - 0x20;`
- reko 0x2D: elsewhere-in-file | `al = al ^ 0x2D;`
- reko 0x2D39: elsewhere-in-file
- reko 0x494C: elsewhere-in-file | `ax -= 0x494C;`
- reko 0x5247: elsewhere-in-file | `ax -= 0x5247;`
- reko 0x532D: elsewhere-in-file

### 3F25 (handler=S)

- reko 0x49: elsewhere-in-file
- reko 0xE800: elsewhere-in-file | `ax = ax - 0xE800;`

### 4050 (handler=T)

- reko 0xE800: elsewhere-in-file | `ax = ax - 0xE800;`

### 42F1 (handler=U)

- reko 0x49: elsewhere-in-file
- reko 0xE800: elsewhere-in-file | `ax = ax - 0xE800;`

### 437E (handler=V)

- ghidra 0x3: elsewhere-in-file
- ghidra 0x4: elsewhere-in-file
- ghidra 0x6: elsewhere-in-file
- ghidra 0x8: elsewhere-in-file
- ghidra 0x9: elsewhere-in-file
- ghidra 0xF: elsewhere-in-file | `bVar3 + (9 < (bVar3 & 0xf) | in_AF) * -6 + (0x99 < bVar3 || *(char *)0xdb ==  ) * -0x60;`
- ghidra 0x10: elsewhere-in-file | `if ((bVar3 == 0x10) || ((0x77 < bVar3 && (bVar3 < 0xf0)))) {`
- ghidra 0x19: elsewhere-in-file | `*(undefined1 *)0x19 = 0;`
- ghidra 0x1A: elsewhere-in-file | `*(undefined1 *)0x1a = 0;`
- ghidra 0x23: elsewhere-in-file | `*(undefined1 *)0x23 = 0x20;`
- ghidra 0x24: elsewhere-in-file | `*(undefined1 *)0x24 = 0x20;`
- ghidra 0x4A: elsewhere-in-file | `if ((*(char *)0xdb ==  ) || (3 < *(byte *)0x4a)) {`
- ghidra 0x60: elsewhere-in-file | `bVar3 + (9 < (bVar3 & 0xf) | in_AF) * -6 + (0x99 < bVar3 || *(char *)0xdb ==  ) * -0x60;`
- ghidra 0x70: elsewhere-in-file | `else if (bVar3 == 0x70) {`
- ghidra 0x77: elsewhere-in-file | `if ((bVar3 == 0x10) || ((0x77 < bVar3 && (bVar3 < 0xf0)))) {`
- ghidra 0x99: elsewhere-in-file | `bVar3 + (9 < (bVar3 & 0xf) | in_AF) * -6 + (0x99 < bVar3 || *(char *)0xdb ==  ) * -0x60;`
- ghidra 0xF0: elsewhere-in-file | `if ((bVar3 == 0x10) || ((0x77 < bVar3 && (bVar3 < 0xf0)))) {`
- ghidra 0x2A5C: absent-from-file | `puVar6 = (undefined1 *)0x2a5c;`
- ghidra 0x2AF8: absent-from-file | `puVar6 = (undefined1 *)0x2af8;`
- ghidra 0x2B37: absent-from-file | `puVar6 = (undefined1 *)0x2b37;`
- ghidra 0x43CF: absent-from-file | `FUN_1000_4b4e(0x43cf);`
- ghidra 0xFFFE: absent-from-file | `puVar6 = &stack0xfffe;`
- reko 0x10: elsewhere-in-file

### 43F3 (handler=W)

- reko 0x800: elsewhere-in-file

### 4542 (handler=Y)

- reko 0x48: elsewhere-in-file

### 4F69 (stratified)

- ghidra 0x6: elsewhere-in-file
- ghidra 0x8: elsewhere-in-file
- ghidra 0x16: elsewhere-in-file | `pcVar1 = (code *)swi(0x16);`
- ghidra 0x60: elsewhere-in-file | `if ((0x60 < bVar2) && (bVar2 < 0x7b)) {`
- ghidra 0x74: elsewhere-in-file | `uVar3 = *(int *)0x74 - 0x200;`
- ghidra 0x7B: elsewhere-in-file | `if ((0x60 < bVar2) && (bVar2 < 0x7b)) {`
- ghidra 0xDF: elsewhere-in-file | `uVar3 = CONCAT11(0xff,bVar2 & 0xdf);`
- ghidra 0xFF: elsewhere-in-file | `*(byte *)0x54d = *(byte *)0x54d ^ 0xff;`
- ghidra 0x200: elsewhere-in-file | `uVar3 = *(int *)0x74 - 0x200;`
- ghidra 0x54D: elsewhere-in-file | `*(byte *)0x54d = *(byte *)0x54d ^ 0xff;`
- ghidra 0x554: elsewhere-in-file | `if (*(uint *)0x554 <= uVar3) {`
- ghidra 0x3A01: elsewhere-in-file | `if (uVar3 < 0x3a01) {`
- ghidra 0x4F09: elsewhere-in-file | `if ((char)(param_1 >> 8) == *(char *)(iVar4 + 0x4f09)) {`
- ghidra 0x4F0A: elsewhere-in-file | `param_1 = (uint)*(byte *)(iVar4 + 0x4f0a);`
- ghidra 0x7300: elsewhere-in-file | `if (param_1 != 0x7300) {`
- ghidra 0x7400: elsewhere-in-file | `if (param_1 == 0x7400) {`

### 5AFF (stratified)

- ghidra 0x3: elsewhere-in-file | `(in_AL = *(char *)0x5 + *(char *)0x3, in_AL < 0x40)) goto  x00015aff;`
- ghidra 0x5: elsewhere-in-file | `*(char *)0x5 = *(char *)0x5 +  ;`
- ghidra 0x8: elsewhere-in-file
- ghidra 0x10: elsewhere-in-file | `} while ((char)iVar3 != -0x10);`
- ghidra 0x13: elsewhere-in-file | `*(undefined1 *)0x2df = *(undefined1 *)0x13;`
- ghidra 0x14: elsewhere-in-file | `*(undefined1 *)0x14 = *(undefined1 *)0x2df;`
- ghidra 0x15: elsewhere-in-file | `*(undefined1 *)0x15 = *(undefined1 *)0x2cb;`
- ghidra 0x16: elsewhere-in-file | `*(undefined1 *)0x16 = *(undefined1 *)0x2f3;`
- ghidra 0x17: elsewhere-in-file | `*(undefined1 *)0x17 = *(undefined1 *)0x2e0;`
- ghidra 0x18: elsewhere-in-file | `*(undefined1 *)0x18 = *(undefined1 *)0x2de;`
- ghidra 0x2E: elsewhere-in-file | `else if (bVar2 != 0x2e) goto FUN_1000_5b4b;`
- ghidra 0x40: elsewhere-in-file | `if (((byte)(*(char *)0x4 + *(char *)0x2) < 0x40) &&`
- ghidra 0x7F: elsewhere-in-file | `*(byte *)(iVar3 + 0x372) = *(byte *)(iVar3 + 0x272) & 0x7f;`
- ghidra 0x80: elsewhere-in-file | `bVar2 = bVar2 | 0x80;`
- ghidra 0x272: elsewhere-in-file | `*(byte *)(unaff_DI + 0x272) = bVar2;`
- ghidra 0x2CB: elsewhere-in-file | `*(undefined1 *)0x15 = *(undefined1 *)0x2cb;`
- ghidra 0x2DE: elsewhere-in-file | `*(undefined1 *)0x18 = *(undefined1 *)0x2de;`
- ghidra 0x2DF: elsewhere-in-file | `*(undefined1 *)0x14 = *(undefined1 *)0x2df;`
- ghidra 0x2E0: elsewhere-in-file | `*(undefined1 *)0x17 = *(undefined1 *)0x2e0;`
- ghidra 0x2F3: elsewhere-in-file | `*(undefined1 *)0x16 = *(undefined1 *)0x2f3;`
- ghidra 0x372: elsewhere-in-file | `if (bVar2 == *(byte *)(unaff_DI + 0x372)) {`
- ghidra 0x54E: elsewhere-in-file | `if (*(char *)0x54e == -1) {`


---

## v2 refresh (night run, merged 1125-seed corpus)

Sample re-drawn on the expanded data: 44 functions (26 handlers + 18 stratified) ->
10 verified, 25 mismatch, 9 no-claims. Same cause classes as above; the expanded corpus
makes the scale explicit:

- **Ghidra**: of 497 `ok` functions, 134 assert at least one constant absent from the whole
  file — 36 large flow-runaway bodies (>=50 fabs, the 080D family) + 98 small-body runaways
  concentrated in the startup region (0x100-0x1xx: relocation-fixup/self-modifying code).
  363 `ok` functions assert nothing contradicted by the bytes.
- **Reko**: exactly **2** fabricated constants in the entire 1125-procedure corpus
  (0x0A5F, 0x4FA5). Reko's pseudo-C is byte-honest everywhere else; its mismatches are
  lowering artifacts (Class B) and boundary drift (Class C).
- The full-corpus per-entry verdicts are in `disasm/bytecheck-full.tsv`; the asm ground truth
  (`disasm/ultimaii.asm`) re-assembles byte-identically (`tools/verify_asm.sh`).

Gate position unchanged: zero unflagged mismatches; every mismatch class-annotated; the two
isolated Reko fabrications plus the Ghidra flow-runaway boundary problem are Phase 2 work.
