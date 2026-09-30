# Verification evidence

This records completed checks, not a prediction of competition acceptance.

## Published 0.2.1 and remote verification

- Release commit: `b1d014fe479081d17ced3d1b6f4541429e440a55`.
- [Successful release CI 36698506212](https://github.com/sgy1023-crt/MoonCassowary/actions/runs/36698506212): all five jobs succeeded, including Ubuntu `wasm-gc` / `js` / `native`, Windows `native`, and reproducibility. Each target passes 252 tests and executes all four examples; both native jobs execute the checked release-mode benchmark.
- `moon publish` returned **200 OK**, exit 0. `moon search sgy1023-crt/cassowary` confirms **0.2.1**.
- [GitHub v0.2.1 Release](https://github.com/sgy1023-crt/MoonCassowary/releases/tag/v0.2.1) points to the exact release commit. The attached published package ZIP has SHA-256 `0ca9adc27c149bad80b8e12a823b85db20ca9af10f6f9c6eff68aee1fb69ddd7`; the GitHub asset digest matches the local archive. Its 43 file entries include the upstream license and no Git metadata, build directories or private configuration.
- A new consumer outside the source checkout ran `moon add sgy1023-crt/cassowary@0.2.1`, which downloaded the registry dependency. Strict checking and **3/3 consumer tests passed on each of Wasm-GC, JavaScript and native**. Tests exercise editable/clamped widths, constraint inspection and removal, invalid tolerance errors with preserved state, tied edit objectives and recovery. The installed `solver.mbt` SHA-256 matches the release source: `7bd32ece05f5683093b54508adad5ef2abc3b9e1a42585e3c2ae250eb77a7758`.
- [Historical v0.2.0 Release](https://github.com/sgy1023-crt/MoonCassowary/releases/tag/v0.2.0) was added at its original commit `cec84ad`, not at the later fixes.

The first real upload encountered a transport/body error; registry search still returned 0.2.0. A retry completed with 200 OK, followed by the independent installation above. The CLI's dry run returned exit 255 despite a server response of `202 Accepted: Dry run completed successfully`; that dry run alone is **not** used as publication evidence. The initial consumer harness placed test-only imports in the normal import block; strict checking rejected unused imports. Moving them to `for "test"` fixed the harness without disabling warnings or changing the published library.

## Current local verification (2026-09-30)

The fixes through `70fce82` passed the following checks on Windows 11 x64, Intel Core i5-12450H, MSVC, `moon 0.1.20260904` and `moonc v0.10.12+1634b282e`:

- `moon fmt --check` and `moon info`, followed by a clean generated-interface diff.
- `moon check --deny-warn`, `moon build`, and `moon test --deny-warn` on each of `wasm-gc`, `js`, and `native`.
- **252 tests passed, zero failures, on each backend.**
- All four examples actually executed on each backend: equations, split_pane, panels, recovery.
- `python tests/oracle/generate.py --check` passed with test-only `kiwisolver==1.4.9`; no fixture drift.
- The release-mode native benchmark executed 18 samples with per-edit assertions enabled.

The local checks above and the exact release CI are separate completed runs. Historical results below are retained as history, not substituted for the release's 252-test matrix.

## Test inventory

| Category | Tests | What is checked |
|---|---:|---|
| Independent Kiwi oracle | 192 | 7,344 add/remove/edit snapshots; raw hard residuals and weighted L1 objective; 768 pinned snapshots additionally compare unique values |
| Upstream solver behavior | 10 | applicable behavior from the fixed Kiwi version, with precise exception assertions |
| Public API / recovery | 22 | identity, independent solvers, reset, conflicts and continued use, duplicate/unknown operations, invalid inputs and weighted preferences |
| Satisfaction assertions | 8 | required/soft residuals, empty solvers, finite nonnegative tolerance contract, invalid-input recovery |
| Constraint inspection | 4 | relation, strength, required status and expression rendering |
| Competing edits | 6 | compatible edits, minimums, tied optima, differing/custom weights, both suggestion orders and edit removal |
| Numeric / tableau | 7 | overflow cannot look like zero violation, rollback after overflow, row substitution/copy, cancellation and pivot guard |
| Public method compatibility | 1 | explicit equality/hash/debug methods usable by external callers |
| Benchmark model | 2 | feasible resize and wraparound, clamping and subsequent expansion at 4/8/16 columns |
| **Total** | **252** | Actual test runner total, not the number of generated numeric literals |

The oracle uses fixed seed `0xC4550A` and Kiwi 1.4.9. It does not invoke MoonCassowary when producing expected answers. General underdetermined systems compare hard residuals and weighted objective, not an arbitrary unique solution. The checked-in large fixture body is generated test data, not handwritten implementation size.

## Verified regressions

- **Benchmark model:** a new feasible-resize regression failed on the old model with `1200 != 1300` (exit 2). Removing the required fixed-width equality allows actual resizing; both benchmark regression tests now pass. Every measured edit checks the solved width, column sum, column minimums and required residuals. Setup/validation errors propagate instead of being printed as successful zero throughput.
- **Edit semantics:** equal-strength conflicting edits minimize total weighted error; they imply neither first-write-wins nor last-write-wins. Both suggestion orders are checked for `left + right = 100` with requests 30 and 40, whose minimum combined edit error is 30. Removing an edit restores the remaining preference. Custom weights 2:1 select the stronger preference in either order. No tableau algorithm was changed for these tests.
- **Panels:** the 40% list share is correctly described as soft. The demo asserts required residuals at each step and verifies actual resize/drag values and the clamped edit objective. Errors propagate out of `main`; floating-point sizes are no longer truncated to integers.
- **Tolerance:** three new tests failed before the guard (exit 2), then passed with finite, nonnegative validation. NaN, both infinities and negative tolerances raise `InvalidNumber`; zero, negative zero and large finite tolerances are accepted. Rejected checks do not change the solver or prevent subsequent edits.

## Benchmark method and observations

Run `moon run bench/main --target native --release`.

Each sample creates a fresh model, warms it for 128 edits, then measures 2,000 edits on that persistent solver. There are three samples for each column count and scenario. Measured time **includes per-edit correctness validation and snapshot rollback overhead**, but excludes setup and warmup. It is not isolated simplex speed or a comparison with another library.

- `feasible-resize`: requests cycle from 1200 through 1249.5, then back to 1200. The actual window and column sum follow every request.
- `clamped-minimum`: requests stay below `40 * columns`; the actual layout stays at its hard minimum. This deliberately non-resizing workload is reported separately.
- `@env.now()` returns Unix-epoch milliseconds, not a monotonic clock. A backwards reading fails before unsigned subtraction. Zero elapsed time reports `unavailable`, never a fabricated rate. Wall-clock adjustments, timer resolution and machine load limit these observations; no performance threshold gates CI.

On the machine above, one completed release-mode run on 2026-09-30 recorded:

| Columns | Feasible resize, 3 samples (ms) | Clamped minimum, 3 samples (ms) |
|---|---|---|
| 4 | 20, 24, 24 | 19, 20, 19 |
| 8 | 29, 32, 32 | 31, 31, 31 |
| 16 | 55, 55, 63 | 52, 54, 53 |

Old 0.2.0 throughput numbers measured suggestions against a hard-fixed width. They are **not evidence of actual layout-resize throughput** and are superseded by this method. Values will vary across machines and runs.

## Runnable use cases

- `moon run examples/equations`: two simultaneous equations, `x=7`, `y=3`.
- `moon run examples/split_pane`: one persistent solver, seven updates. Requested width 400 produces width 496 to preserve required minimum sizes; later expansion and dragging reuse the solver.
- `moon run examples/panels`: open at 1280, resize to 1024, drag sidebar to 500, then request an infeasibly narrow window. The drag produces main width 512, list approximately 204.8 and detail approximately 307.2. The narrow request solves to window 612 in this run. Maximum required residual over the run was approximately `1.14e-13`, below `1e-8`.
- `moon run examples/recovery`: reject a contradictory hard constraint, then edit and remove normally; state is not poisoned by failure.

## Historical checks (not current release evidence)

- [0.2.0 CI run 36686511364](https://github.com/sgy1023-crt/MoonCassowary/actions/runs/36686511364), commit `cec84ad`: 245 tests; predates the benchmark, panel and tolerance fixes above.
- [Initial CI run 36445064001](https://github.com/sgy1023-crt/MoonCassowary/actions/runs/36445064001), commit `f4f9366`: 232 tests and three examples. The initial compiler failure was fixed by explicit `pub extend` declarations, not by disabling warnings.
- A fresh public clone during 0.1.0 verification exposed Windows CRLF drift in generated fixtures. `.gitattributes` now fixes text to LF; the strict oracle comparison is retained.

No cross-library speedup, production adoption, or complete UI-framework claim is made. Snapshot rollback is O(tableau size) per operation. Inspection and violation APIs do not extract minimal conflict sets. See `THIRD_PARTY_NOTICES.md` and `docs/ECOSYSTEM.md` for source and algorithm boundaries.
