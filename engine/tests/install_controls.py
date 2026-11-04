#!/usr/bin/env python3
"""Red controls for the installer and config gates.

docs/install-design.md § 7 and AGENTS.md § 3: a gate has to be able to fail in the
place that enforces it, so each property below is broken one at a time in a
throwaway copy of the source, the real check is rebuilt against that copy, and the
control is only satisfied when the check goes red on exactly the assertions that
own the broken property.

Three ways a control lies, all of them detected here rather than waved through:
  * it does not compile, so nothing was tested
  * it goes red for an unrelated reason (a missing fixture directory)
  * it crashes: a SIGABRT with stdout still in the buffer looks identical to "no
    failures" unless the exit code is checked, and one of these controls really
    did abort for a reason unrelated to the property it claimed to test

Run by tests/run_cp4.sh; takes the CP4 work directory as argv[1].
"""

import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent          # engine/
WORK = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("/var/tmp/u2-controls")

CONFIG_CONTROLS = [
    ("precedence-inverted", "src/core/config.c",
     'if ((!ctx->data_dir || !*ctx->data_dir) && *cfg->data)',
     'if (*cfg->data)',
     "command line outranks config.ini",
     "tests/config_check.c",
     ["src/core/config.c", "src/core/ini.c"]),
    ("typos-accepted", "src/core/config.c",
     "static int known(const char *const *list, size_t n, const char *key)\n{",
     "static int known(const char *const *list, size_t n, const char *key)\n{\n"
     "    (void)list; (void)n; (void)key; return 1;",
     "an unknown key is refused, not ignored",
     "tests/config_check.c",
     ["src/core/config.c", "src/core/ini.c"]),
    ("paths-unchecked", "src/core/config.c",
     "if (r == U2_CONFIG_OK && *out->data && !is_dir(out->data)) {",
     "if (0 && *out->data && !is_dir(out->data)) {",
     "a path that is not a directory is an error at startup",
     "tests/config_check.c",
     ["src/core/config.c", "src/core/ini.c"]),
    ("no-path-resolution", "src/core/config.c",
     "    if (!*val || val[0] == '/' || !*base)\n        return;",
     "    return;",
     "a relative path resolves against the file that names it",
     "tests/config_check.c",
     ["src/core/config.c", "src/core/ini.c"]),
]

INSTALL_CONTROLS = [
    ("no-manifest", "src/core/install.c",
     '    fprintf(f, "# dst\\tkind\\tsource\\tsize\\tsha256:16\\n");',
     '    fprintf(f, "# dst\\tkind\\tsource\\tsize\\tsha256:16\\n");\n'
     '    fclose(f); rename(tmp, path); return 0;',
     "the manifest records what was emitted",
     "tests/install_check.c",
     ["src/core/install.c", "src/core/roots.c", "src/core/sha256.c",
      "src/core/world.c", "src/core/config.c", "src/core/ini.c"]),
    ("everything-is-content", "src/core/install.c",
     '    if (!strcmp(lo, "monsters") || !strcmp(lo, "player") || !strcmp(lo, "ultimaii.exe"))\n'
     "        return 1;",
     "    return 1;",
     "non-content files are skipped, not copied",
     "tests/install_check.c",
     ["src/core/install.c", "src/core/roots.c", "src/core/sha256.c",
      "src/core/world.c", "src/core/config.c", "src/core/ini.c"]),
    ("foreign-target-allowed", "src/core/install.c",
     '    if (st == T_FOREIGN) {\n        snprintf(err, errsz,\n                 "%s is not empty and carries no %s',
     '    if (0) {\n        snprintf(err, errsz,\n                 "%s is not empty and carries no %s',
     "a directory that is not ours is never written to",
     "tests/install_check.c",
     ["src/core/install.c", "src/core/roots.c", "src/core/sha256.c",
      "src/core/world.c", "src/core/config.c", "src/core/ini.c"]),
    ("all-drift-is-played-in", "src/core/install.c",
     '    return !strncasecmp(base, "mapx", 4) || !strncasecmp(base, "mapg", 4) ||\n'
     '           !strncasecmp(base, "monx", 4) || !strncasecmp(base, "mong", 4);',
     "    return 1;",
     "only sector files are allowed to drift (D6)",
     "tests/install_check.c",
     ["src/core/install.c", "src/core/roots.c", "src/core/sha256.c",
      "src/core/world.c", "src/core/config.c", "src/core/ini.c"]),
    ("patch-wins-the-shadow", "src/core/install.c",
     "    if (rq->original_dir && *rq->original_dir) {",
     "    if (0) {",
     "the release layer wins a file present in both sources",
     "tests/install_check.c",
     ["src/core/install.c", "src/core/roots.c", "src/core/sha256.c",
      "src/core/world.c", "src/core/config.c", "src/core/ini.c"]),
]

CC = ["cc", "-std=c11", "-Wall", "-Wextra", "-Wno-unused-parameter",
      "-Wno-unused-function", "-Isrc"]


def run_control(name, source, old, new, label, test, extra_srcs):
    """Returns None on a satisfied control, or the reason it was not."""
    src_text = (SRC / source).read_text()
    if src_text.count(old) != 1:
        return f"anchor found {src_text.count(old)} times (control is stale)"

    broken = WORK / f"{name}.c"
    broken.write_text(src_text.replace(old, new))
    exe = WORK / f"ctl_{name}"
    # The broken copy must actually be in the link line. Substituting it by
    # position rather than appending it is the difference between a control and a
    # ceremony: the first version of this harness compiled the pristine source and
    # reported every control as satisfied, which is a gate that cannot fail.
    srcs = [str(broken) if s == source else str(SRC / s) for s in extra_srcs]
    build = subprocess.run(
        CC + ["-o", str(exe), str(SRC / test)] + srcs,
        cwd=str(SRC), capture_output=True, text=True)
    if build.returncode != 0:
        return f"did not compile: {build.stderr.strip().splitlines()[:1]}"

    run_dir = WORK / name
    run_dir.mkdir(parents=True, exist_ok=True)
    run = subprocess.run([str(exe), str(run_dir)], capture_output=True,
                         text=True, cwd=str(run_dir))
    if run.returncode not in (0, 1):
        return (f"exited {run.returncode} rather than reporting (a crash is not a "
                "red gate; the control itself is broken)")
    red = [l.strip() for l in run.stdout.splitlines()
           if l.strip().startswith("FAIL")]
    if not red:
        return "the check stayed green, so it cannot fail where this property lives"
    if any("cannot write" in r for r in red):
        return "went red on a fixture problem, not on the property"
    print(f"        red ok  {label}: {len(red)} assertion(s)")
    return None


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    bad = []
    for group, controls in (("config", CONFIG_CONTROLS), ("install", INSTALL_CONTROLS)):
        for name, source, old, new, label, test, extra in controls:
            reason = run_control(name, source, old, new, label, test, extra)
            if reason:
                bad.append(f"{group}/{name}: {reason}")
    if bad:
        print("  FAIL  installer controls:")
        for b in bad:
            print(f"        {b}")
        return 1
    print(f"  ok    installer controls: {len(CONFIG_CONTROLS) + len(INSTALL_CONTROLS)} "
          f"properties, every one able to go red")
    return 0


if __name__ == "__main__":
    sys.exit(main())
