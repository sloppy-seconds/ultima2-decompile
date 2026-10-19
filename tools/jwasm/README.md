# tools/jwasm — vendored JWasm build (gitignored binary)

JWasm v2.21 — MASM-compatible assembler, chosen as the Phase 3 dialect target (AGENTS.md §1).

* **Source:** https://github.com/Baron-von-Riedesel/JWasm (commit cloned 2026-10-19)
* **License:** Sybase Open Watcom Public License (OWPL). Not GPL/AGPL. The binary is vendored
  as re-fetchable tooling (same policy as `tools/spice86/`, `tools/reko/`): gitignored, never
  committed, never linked into project output.
* **Rebuild on Linux:**
  ```sh
  git clone --depth 1 https://github.com/Baron-von-Riedesel/JWasm /var/tmp/jwasm-build
  cd /var/tmp/jwasm-build && make -f GccUnix.mak -j8
  cp build/GccUnixR/jwasm <project>/tools/jwasm/jwasm
  ```
* **Wire-up:** `source tools/env.sh` exports `$JWASM`.
* **Smoke test:** `printf '.8086\n.CODE\nstart:\n mov ax,4C00h\n int 21h\nEND start\n' | ...`
  -> `jwasm -bin -Foout out.asm` yields `b8 00 4c cd 21`. Note: output option is case-sensitive
  `-Fo<file>` (not `-fo=`).
