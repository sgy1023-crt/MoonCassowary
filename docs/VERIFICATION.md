# Verification evidence

This records completed checks, not a prediction of competition acceptance.

## Automated checks

[Successful CI run 36445064001](https://github.com/sgy1023-crt/MoonCassowary/actions/runs/36445064001) verifies the solver at commit `f4f9366`:

- Ubuntu: `wasm-gc`, `js`, `native`; Windows: `native`.
- Each target: strict type check, actual build, test execution and all three examples.
- Separate reproducibility job: `moon fmt --check`, generated interface comparison, Python `kiwisolver==1.4.9` fixture regeneration in check-only mode.

The first CI run failed before tests because the newer compiler requires explicit promotion of derived public trait methods. Explicit `pub extend` declarations and a public-method regression fixed it; warnings were not disabled.

## Test inventory

| Category | Tests | What is checked |
|---|---:|---|
| Independent Kiwi oracle | 192 | 7,344 add/remove/edit snapshots; raw hard residuals and weighted L1 objective; 768 pinned snapshots additionally compare unique values |
| Upstream solver behavior | 10 | applicable behavior from the fixed Kiwi version, with precise exception assertions |
| Public API / recovery | 22 | identity, independent solvers, reset, conflicts and continued use, duplicate/unknown operations, invalid inputs and weighted preferences |
| Numeric / tableau | 7 | overflow cannot look like zero violation, rollback after overflow, row substitution/copy, cancellation and pivot guard |
| Public method compatibility | 1 | explicit equality/hash/debug methods usable by external callers |
| **Total** | **232** | Actual test runner total, not the number of generated numeric literals |

The oracle uses fixed seed `0xC4550A` and Kiwi 1.4.9. It does not invoke MoonCassowary when producing expected answers. General underdetermined systems are not required to produce the same arbitrary variable values as Kiwi. The checked-in large fixture body is generated test data, not handwritten implementation size.

## Local and clean-checkout checks

Local toolchain: `moon 0.1.20260904`, `moonc v0.10.12+1634b282e`; Windows/MSVC. Core tests and actual builds were run in all three supported backends. The final public-method regression was additionally exercised in the CI matrix above.

A fresh clone from the public repository passed native strict checking, tests, and the split-pane example. This caught a Windows checkout issue: global Git `autocrlf` changed 36,839 fixture line endings to CRLF, making the byte-exact oracle checker report drift while normalized contents were identical. `.gitattributes` now fixes repository text to LF; the oracle's strict comparison is retained rather than relaxed.

## Runnable use cases

- `moon run examples/equations`: two simultaneous equations, `x=7`, `y=3`.
- `moon run examples/split_pane`: one persistent solver, seven updates, arbitrary linked variables plus minimum sizes and weighted edits. Requested width 400 produces width 496 to preserve required minimum sizes; hard residuals remain zero. Later expansion and dragging reuse the solver.
- `moon run examples/recovery`: reject a contradictory hard constraint, then edit and remove normally; state is not poisoned by the failure.

No wall-time speedup, production adoption, or complete UI-framework claim is made. Snapshot rollback is deliberately O(tableau size) per operation. For source and algorithm boundaries, see `THIRD_PARTY_NOTICES.md` and `docs/ECOSYSTEM.md`.
