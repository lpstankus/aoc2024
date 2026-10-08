# Advent of Code 2024

25 Zig programs. The build embeds the example and real-input files for each day.

## Reproduce verification

Install [mise](https://mise.jdx.dev/) and Python 3, then run from this directory:

```sh
mise trust
mise install
mise run verify
mise exec -- zig build run-01
```

`mise.toml`, `.zigversion` and the package minimum version all specify Zig 0.17.0, the [current stable release checked on October 8, 2026](https://ziglang.org/download/index.json). There are no external package dependencies.

Verification compiles all 25 programs in Debug through `zig build check`, runs the garden-counting unit tests, builds in ReleaseSafe, and compares every program's transcript against `verification/outputs.json`. The default per-program timeout is 180 seconds. Fixture hashes detect changed or missing inputs. Day 18's tuple punctuation is normalized because Zig 0.17 adds a dot before the braces; the coordinates remain checked.

## Baseline and changes

The source baseline is commit `0a0242276359e14497b099c0d85b0b972b282a0e`. Its `.zigversion` pinned 0.14.0. All 25 programs built in ReleaseSafe and ran with the original inputs and examples before changes. No original unit tests existed.

Compatibility updates use build modules, managed array lists, DebugAllocator, intrusive linked-list nodes, splat initialization and the new priority-queue allocation and push/pop APIs. Solver behavior remains unchanged except for the garden bug found during comparison.

Day 12's old recursive border traversal depended on hash-map iteration order. Its baseline part 2 answers were 1451 for the example and 1028067 for the input. Counting straight sides by their first edge gives 1206 and 881182. Independent flood-fill and corner counting verified both corrected values. Tests cover a single plot, a rectangle, a concave corner, a hole and the supplied example.

The other 24 days match the baseline outputs. Output snapshots provide regression evidence, not an independent proof for every solution. The day 12 snapshots deliberately contain the independently verified corrections.
