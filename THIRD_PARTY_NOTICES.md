# Third-party provenance

MoonCassowary is a **MoonBit port of Kiwi**, not an independently invented constraint algorithm and not an FFI wrapper.

- Upstream: [nucleic/kiwi](https://github.com/nucleic/kiwi)
- Fixed baseline: **1.4.9**, commit [`728f5661fdd021c68dac1b914b3c8610a46b2e7e`](https://github.com/nucleic/kiwi/tree/728f5661fdd021c68dac1b914b3c8610a46b2e7e)
- Upstream copyright: Copyright (c) 2013-2025, Nucleic Development Team.
- License: Modified BSD / BSD-3-Clause; the unmodified upstream license is in `licenses/Kiwi-LICENSE`.

## Ported and adapted material

| MoonCassowary | Upstream baseline |
|---|---|
| `row.mbt` | `kiwi/row.h`, `kiwi/symbol.h` |
| `tableau.mbt` | `kiwi/solverimpl.h` |
| `strength.mbt` | `kiwi/strength.h`, `kiwi/util.h` |
| public expression/constraint/variable/solver API | concepts from the corresponding `kiwi/*.h`, redesigned for MoonBit |
| `upstream_test.mbt` | applicable solver behavior from `py/tests/test_solver.py` |

The port preserves the sparse tableau, marker tracking, artificial-variable feasibility phase, primal optimization, and dual optimization for edit suggestions. It replaces C++ pointers/exceptions with MoonBit handles, maps and typed errors; values are queried from a solver, not stored in shared variable objects. Mutations have deep-snapshot rollback. Symbol-ID tie breaking is explicit. Non-finite input and out-of-range strengths are rejected rather than passed through/clipped. Numerical failures and a 10,000-pivot per-operation limit restore the old state.

CPython bindings, C++ expression operators, debug dump formatting, and upstream platform/build machinery are not ported. No affiliation or endorsement by Kiwi, its contributors, or any competition organizer is claimed.

## Independent oracle

`tests/oracle/generate.py` uses Python `kiwisolver==1.4.9` only to generate and check test expectations. That package is not imported by any MoonBit runtime code. The generated tests carry their seed and provenance; their large fixture body is **test data, not handwritten implementation volume**. Unique solutions are compared by values; general systems are checked by raw residuals and weighted objective, allowing different valid solutions to underdetermined systems.

Standard-library imports are from MoonBit core. No external runtime solver, service or model API is used.
