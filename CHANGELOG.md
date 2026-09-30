# Changelog

## 0.2.1 — 2026-09-30

- Fix the benchmark's required fixed-width constraint so the feasible-resize scenario actually resizes. Validate solved widths, column sums, minimums and residuals on every edit; separate clamped scenarios, exclude setup/warmup and report three samples. Propagate failures and never fabricate zero-time throughput.
- Correct equal-strength edit documentation and tests: compatible suggestions can both hold; conflicting suggestions minimize weighted L1 error and can have multiple optima. Add order-independent objective and custom-weight regressions.
- Assert the multi-panel demo's resize, drag and clamping behavior, preserve fractional sizes, propagate errors, and execute it on every CI target. Run native benchmarks in release mode.
- Require finite, nonnegative `Solver::is_satisfied` tolerances; invalid values raise `InvalidNumber` without changing solver state. Zero remains valid.
- 252 tests total. Refresh current verification evidence and distinguish historical 0.1.0/0.2.0 results.

## 0.2.0

- Add `Solver::maximum_required_violation` and `Solver::is_satisfied` so callers can assert a solved layout without re-deriving residuals.
- Add `Constraint::relation`, `strength`, `is_required` and `to_repr`, so a rejected conflicting constraint can be inspected instead of only reported.
- Add a four-panel nested layout example where a window resize and a divider drag are both suggestions competing against hard minimums.
- Add four regression tests for competing edit variables, including strength ordering and what happens when one is removed. Every expectation in them was taken from Kiwi 1.4.9, not assumed; two initial assertions were corrected against upstream.
- Add a repeatable native benchmark for the incremental edit path (4/8/16 columns) and run it in CI. Numbers are raw single-run measurements, not a comparison with Kiwi.
- 245 tests total.

## 0.1.0

- Port Kiwi 1.4.9's sparse tableau solver to MoonBit, including marker-based constraint removal, artificial-variable feasibility, primal and dual optimization, and edit suggestions.
- Provide identity-based immutable input handles and solver-local solution values.
- Add transactional rollback, finite-input/arithmetic guards, deterministic symbol tie breaking, and a per-operation pivot limit.
- Provide runnable equations, interactive split-pane relationships and conflict-recovery examples.
- Add 232 tests, including fixed-seed independent Kiwi oracle scenarios and overflow/recovery regressions.
- Verify native, JS and Wasm-GC in CI; verify Windows and Linux native builds. Retain upstream BSD license and exact provenance.
- Make derived public methods explicit for newer MoonBit compilers; enforce LF checkout for reproducible fixtures on Windows.

This is a separate project from MoonCheck, with a different algorithm, data model and purpose. It does not replace or rename the old repository.
