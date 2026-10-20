# data_4815 — DATA ISLAND, not code: Phase 2 defect verdict
#            (disasm/defects.md): the region decodes only as absurd instructions
#            (fisttps / negative displacements); bytecheck FP adjudicated.
#            CP5 disposition: data. Bytes byte-proven via check_func.py.
# func 4815..4821  len 000D B  evidence: reko (island inside seed range)
# confidence: high (defect verdict documented)
data_4815_mixed:
L_004a15:
        db 0xdf,0x88,0x1e,0x1f,0x00,0x8b,0xc7,0xf8,0x14,0x24,0xe8,0x6a,0x08        # mixed: island bytes
