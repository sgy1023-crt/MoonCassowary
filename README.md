# MoonCassowary

[![CI](https://github.com/sgy1023-crt/MoonCassowary/actions/workflows/ci.yml/badge.svg)](https://github.com/sgy1023-crt/MoonCassowary/actions)

**面向交互布局的 MoonBit 原生增量线性约束求解库。**

A pure MoonBit port of [Kiwi 1.4.9](https://github.com/nucleic/kiwi/tree/728f5661fdd021c68dac1b914b3c8610a46b2e7e), the Cassowary-family incremental constraint solver. It solves equations and inequalities, balances weighted preferences, and reuses a tableau while constraints or edit suggestions change. **It does not call C++, Python, JavaScript solvers, or remote services.**

## Why this library

An interactive layout can say:

- sidebar + gap + content = window width;
- sidebar is at least 160, content at least 320;
- prefer the dragged sidebar width, unless a stronger constraint wins;
- keep relationships between variables even when constraints are added or removed.

A CSS/Flex/Grid layout tree is not the same API as arbitrary linked linear constraints. A general LP solver can express the mathematics, but this library exposes a persistent add/remove/edit interface directly. It is **not** a replacement for existing MoonBit CSS layout engines, finite-domain solvers, or LP/MIP libraries. See the [dated ecosystem comparison](docs/ECOSYSTEM.md), including those adjacent implementations and the limits of our search.

## Build and run

Requires the [MoonBit toolchain](https://www.moonbitlang.com/download/).

```bash
git clone https://github.com/sgy1023-crt/MoonCassowary
cd MoonCassowary
moon check
moon test
moon run examples/equations
moon run examples/split_pane
moon run examples/panels
moon run examples/recovery
moon run bench/main --target native --release   # edits plus per-edit validation
```

There are no third-party runtime dependencies. The library and examples support `wasm-gc`, `js`, and `native`; native builds require a C toolchain (MSVC on Windows is supported).

To use the published [0.2.1 release](https://github.com/sgy1023-crt/MoonCassowary/releases/tag/v0.2.1):

```bash
moon add sgy1023-crt/cassowary@0.2.1
```

Import `"sgy1023-crt/cassowary" @cassowary` in your `moon.pkg`.

## Minimal example

Constraints compare an affine expression with **zero**. Thus `x + y = 10` is represented by coefficients `[(x, 1), (y, 1)]` and constant `-10`.

```moonbit
let solver = @cassowary.Solver::new()
let x = @cassowary.Variable::new("x")
let y = @cassowary.Variable::new("y")
let sum = @cassowary.Constraint::new(
  @cassowary.Expression::new([(x, 1.0), (y, 1.0)], constant=-10.0),
  @cassowary.Relation::Equal,
)
let difference = @cassowary.Constraint::new(
  @cassowary.Expression::new([(x, 1.0), (y, -1.0)], constant=-4.0),
  @cassowary.Relation::Equal,
)
solver.add_constraint(sum)
solver.add_constraint(difference)
assert_eq(solver.value(x), 7.0)
assert_eq(solver.value(y), 3.0)
```

The mutation calls can raise `SolverError`; the runnable examples include error handling. There is no separate `updateVariables` step: `solver.value(x)` reads the current solution.

## Interactive updates

```moonbit
solver.add_edit_variable(x, @cassowary.strong())
solver.suggest_value(x, 20.0)
```

A suggestion is **not an assignment**. In the example above both hard equations already determine `x = 7`; they win over a soft edit suggestion. Remove a stored constraint handle to relax the model:

```moonbit
solver.remove_constraint(difference)
solver.suggest_value(x, 20.0)
// x = 20, y = -10, while x + y = 10 remains required.
```

`examples/split_pane` keeps one solver while resizing the window and dragging the sidebar. It prints solved sizes, required-constraint residuals, and pivot counts. If the requested window is too narrow, minimum sizes win: the **suggested** width 400 becomes **solved** width 496 (= 160 + 16 + 320). `examples/recovery` demonstrates rejection of a contradictory hard constraint, followed by successful editing and removal on the same solver.

`examples/panels` lays out four nested panels with two edit handles: window width and sidebar width. When both suggestions are compatible with the hard structure and minimums, both can be satisfied. If they conflict, the weighted objective decides the trade-off. Equal strengths do **not** imply last-write-wins or first-write-wins: several solutions can have the same minimum cost. For example, with `left + right = 100` and equal-strength suggestions `left = 30`, `right = 40`, both `(30, 70)` and `(60, 40)` have total edit error 30. The panel proportions, including the list's 40% share, are soft preferences; panel minimums and sum relations are required.

## API and behavior

- `Variable::new(name)`: identity-based variables; equal names do not alias.
- `Expression::new(terms, constant?)`: copies and combines repeated terms.
- `Constraint::new(expression, relation, strength?)`: keep the handle for later removal.
- `Solver::add_constraint`, `remove_constraint`, `has_constraint`.
- `Solver::add_edit_variable`, `remove_edit_variable`, `has_edit_variable`, `suggest_value`.
- `Solver::value`, `reset`, `statistics`.
- `Solver::is_satisfied` and `maximum_required_violation`: assert a solved layout without re-deriving residuals by hand. `is_satisfied(tolerance=...)` requires a finite, nonnegative tolerance (default `1e-8`); invalid tolerances raise `InvalidNumber`, and zero requests an exact residual check.
- `Constraint::relation`, `strength`, `is_required`, `to_repr`: inspect a constraint, including one that was rejected as unsatisfiable.
- `Expression::value` and `Constraint::violation`: inspect solved residuals; these can raise `InvalidNumber` or `NumericalFailure` rather than letting overflow/NaN look like a satisfied inequality.

Strengths: `required()` is hard; `strong()` = 1,000,000, `medium()` = 1,000, `weak()` = 1. Soft constraints minimize weighted L1 violations. These are **scalar weights, not infinite lexicographic priorities**: enough weak constraints can outweigh one strong constraint. Custom finite strengths in `[0, required()]` are accepted; an edit cannot be required.

Variables can be reused in separate solvers without sharing solved values. Unknown/nonbasic variables read as zero. Constraint identity matters: adding the same handle twice is an error, while distinct equivalent constraints are allowed.

## Errors and limits

Typed errors cover duplicate/unknown constraints and edit variables, unsatisfiable required constraints, invalid strengths/numbers, numerical failures and the pivot limit. A failed mutation restores the previous numerical state. `examples/recovery` and the regression tests exercise continued use after errors.

- Snapshot rollback costs **O(tableau size)** time and memory per mutation. The basis is still reused; it is not a cold solve. This is a correctness-first implementation, **not** a claim to match Kiwi's speed or memory usage.
- Floating-point solver, not exact arithmetic: the port uses Kiwi's absolute near-zero threshold `1e-8`. Scale inputs sensibly; coefficients below that threshold may be discarded.
- Each mutation is capped at 10,000 optimization/removal pivots. Resource or numerical errors are reported, not silently accepted as solutions.
- Removed variable symbols can remain until `reset`, as in Kiwi. Statistics distinguish explicit constraints from edit registrations.
- Handle identities use a process-local monotonic counter. Creation is intended for a single MoonBit runtime/thread; IDs are not serialization keys. Identity-space exhaustion aborts rather than aliases handles.
- No integer/nonlinear optimization, CSS rendering, general LP file interchange, or guaranteed unique solution for underdetermined systems.

## Tests and reproducibility

**252 tests pass on each of wasm-gc, js and native.** This includes 192 independent oracle scenarios with 7,344 checked operation snapshots and 768 uniquely determined snapshots, 10 upstream behavior ports, 22 API/recovery tests, 8 satisfaction-assertion tests, 4 constraint-inspection tests, 6 competing-edit tests, 7 numeric/tableau regressions, one public-method compatibility test and 2 benchmark-model tests. See [verification evidence](docs/VERIFICATION.md).

The benchmark reports feasible resizing separately from minimum-clamped edits, with 128 warmup edits and three 2,000-edit samples per scenario/size. Timing includes per-edit validation, excludes setup/warmup, and uses millisecond wall-clock readings. It is not a cross-library speed comparison; old 0.2.0 numbers from a hard-fixed window do not measure actual resizing.

To reproduce oracle expectations:

```bash
python -m pip install kiwisolver==1.4.9
python tests/oracle/generate.py --check
```

Python is **test-only**. Checked-in tests run with `moon test` without Python. The generator uses a fixed seed; `--check` compares against a temporary regeneration and does not overwrite checked-in expectations. General cases compare raw hard-constraint residuals and weighted objective; only uniquely determined cases compare every variable value.

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc
moon test --target wasm-gc
moon check --target js --deny-warn
moon build --target js
moon test --target js
moon check --target native --deny-warn
moon build --target native
moon test --target native
moon info
```

Generated oracle fixtures are not counted as handwritten solver code. CI runs actual build/test tasks, examples, formatting, interface consistency and oracle regeneration checks.

## Source and license

BSD-3-Clause. Core algorithms are ported from **nucleic/kiwi 1.4.9**, not claimed as original inventions. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the exact revision, source-file mapping, adaptations, omitted upstream features and test provenance. The original upstream license is retained in `licenses/Kiwi-LICENSE`.
