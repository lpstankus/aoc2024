"""Run every implemented day against recorded example and real-input outputs."""

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

LANGUAGE = "zig"
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--timeout", type=int, default=180, help="Seconds allowed per solution")
if LANGUAGE == "c":
    parser.add_argument("--completed", action="store_true", help="Check completed days 1-3 only")
args = parser.parse_args()
expected = json.loads((ROOT / "verification/outputs.json").read_text())
env = os.environ.copy()
if LANGUAGE == "odin":
    env.pop("ODIN_ROOT", None)


def run(command, timeout):
    try:
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        print("FAIL timed out:", " ".join(command), flush=True)
        return None
    if result.returncode:
        print("FAIL:", " ".join(command), flush=True)
        print(result.stdout + result.stderr)
        return None
    return result.stdout + result.stderr


def normalize(output, day):
    # Rust day 4 prints rooms from a HashMap whose iteration order can change.
    lines = output.strip().splitlines()
    if LANGUAGE == "rust" and day == "day04":
        rooms = sorted(line for line in lines if re.match(r"^\d+ -> ", line))
        index = 0
        for i, line in enumerate(lines):
            if re.match(r"^\d+ -> ", line):
                lines[i] = rooms[index]
                index += 1
    # Zig 0.17 adds a dot to the tuple representation printed by day 18.
    if LANGUAGE == "zig" and day == "day18":
        lines = [line.replace("part 2: .{", "part 2: {") for line in lines]
    return "\n".join(lines) + "\n"


for name, digest in expected["fixtures"].items():
    path = ROOT / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        sys.exit("FAIL missing or changed fixture: " + name)

if LANGUAGE == "rust":
    for command in [["cargo", "test", "--workspace", "--locked"],
                    ["cargo", "build", "--workspace", "--release", "--locked"]]:
        if run(command, 600) is None:
            sys.exit(1)
    sources = sorted(ROOT.glob("src/*/src/main.rs"))
elif LANGUAGE == "zig":
    for command in [["zig", "build", "check", "-j2"], ["zig", "build", "test", "-j2"],
                    ["zig", "build", "-Doptimize=ReleaseSafe", "-j2"]]:
        if run(command, 600) is None:
            sys.exit(1)
    sources = sorted(ROOT.glob("src/*.zig"))
elif LANGUAGE == "odin":
    sources = sorted(ROOT.glob("src/day*/main.odin"))
else:
    sources = sorted(ROOT.glob("src/day*/main.c"))

(ROOT / "out").mkdir(exist_ok=True)
passed = 0
failed = 0
for source in sources:
    if LANGUAGE == "rust":
        day = "day" + source.parent.parent.name
        binary = ROOT / "target/release" / day
    elif LANGUAGE == "zig":
        day = "day" + source.stem
        binary = ROOT / "zig-out/bin" / ("aoc2024-" + source.stem)
    else:
        day = source.parent.name
        binary = ROOT / "out" / day
        if LANGUAGE == "c" and args.completed and day not in expected["outputs"]:
            print("UNFINISHED", day, "excluded by --completed", flush=True)
            continue
        if LANGUAGE == "odin":
            command = ["odin", "build", str(source.parent), "-o:speed", "-out:" + str(binary)]
        else:
            command = ["make", "-B", day]
        if run(command, 180) is None:
            failed += 1
            continue
    if day not in expected["outputs"]:
        print("UNVERIFIED", day, "has no completed baseline", flush=True)
        failed += 1
        continue
    output = run([str(binary)], args.timeout)
    if output is None:
        failed += 1
        continue
    actual = normalize(output, day)
    golden = expected["outputs"][day]
    if actual != golden:
        print("FAIL", day, "output changed", flush=True)
        print("".join(difflib.unified_diff(golden.splitlines(True), actual.splitlines(True),
                                          fromfile="expected", tofile="actual")))
        failed += 1
        continue
    print("PASS", day, "recorded solution outputs", flush=True)
    passed += 1

print(f"{passed} output regressions passed; {failed} failed or unavailable. See README.md for correctness limits.")
sys.exit(1 if failed else 0)
