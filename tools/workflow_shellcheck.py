#!/usr/bin/env python3
"""Render each `run:` block of a workflow with the matrix values substituted, and
bash -n the result. Catches shell syntax errors that Actions only reports after a
full build, which on this workflow costs minutes per attempt."""
import subprocess, sys, yaml, re, pathlib

wf = pathlib.Path(".github/workflows/release-builds.yml")
doc = yaml.safe_load(wf.read_text())

variants = [
    {"matrix.name": "linux-static", "matrix.artifact": "u2-sdl-static",
     "matrix.make_target": "sdl-static", "matrix.sdl_flags": ""},
    {"matrix.name": "windows-cross", "matrix.artifact": "u2-sdl.exe",
     "matrix.make_target": "sdl-win",
     "matrix.sdl_flags": "-DCMAKE_SYSTEM_NAME=Windows"},
]
env = {"SDL3_VERSION": "3.4.18"}
ref = "v0.0.0-test"

fails = 0
for job in doc.get("jobs", {}).values():
    for step in job.get("steps", []):
        run = step.get("run")
        if not run:
            continue
        for v in variants:
            s = run
            for k, val in v.items():
                s = s.replace("${{ " + k + " }}", val)
            s = s.replace("${{ github.ref_name }}", ref)
            for k, val in env.items():
                s = s.replace("${{ env." + k + " }}", val)
            s = re.sub(r"\$\{\{[^}]*\}\}", "SUBST", s)
            p = subprocess.run(["bash", "-n"], input=s, text=True,
                               capture_output=True)
            if p.returncode != 0:
                fails += 1
                print(f"FAIL  {step.get('name','?')} [{v['matrix.name']}]: {p.stderr.strip()}")
            else:
                print(f"ok    {step.get('name','?')} [{v['matrix.name']}]")

print()
print("WORKFLOW SHELL: PASS" if fails == 0 else f"WORKFLOW SHELL: FAIL ({fails})")
sys.exit(1 if fails else 0)
