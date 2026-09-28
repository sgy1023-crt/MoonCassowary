// Copyright (c) 2014-2024, Nucleic Development Team.
// Copyright (c) 2026, MoonCassowary contributors (MoonBit adaptation).
// BSD-3-Clause; full retained license: tests/oracle/LICENSE.kiwi.
// Ported behavioral tests from Nucleic/kiwi py/tests/test_solver.py,
// commit 728f5661fdd021c68dac1b914b3c8610a46b2e7e (Kiwi 1.4.9).
// Deliberately excludes CPython type errors, exception object payloads, and
// dump formatting, which are not part of this typed MoonBit public API.
// Values are solver-owned; no updateVariables() call is necessary.

///|
fn upstream_eq(
  terms : Array[(@cassowary.Variable, Double)],
  constant : Double,
  strength? : Double = 1001001000.0,
) -> @cassowary.Constraint {
  @cassowary.Constraint::new(
    @cassowary.Expression::new(terms, constant~),
    @cassowary.Relation::Equal,
    strength~,
  )
}

///|
fn upstream_le(
  terms : Array[(@cassowary.Variable, Double)],
  constant : Double,
  strength? : Double = 1001001000.0,
) -> @cassowary.Constraint {
  @cassowary.Constraint::new(
    @cassowary.Expression::new(terms, constant~),
    @cassowary.Relation::LessEqual,
    strength~,
  )
}

///|
fn upstream_ge(
  terms : Array[(@cassowary.Variable, Double)],
  constant : Double,
  strength? : Double = 1001001000.0,
) -> @cassowary.Constraint {
  @cassowary.Constraint::new(
    @cassowary.Expression::new(terms, constant~),
    @cassowary.Relation::GreaterEqual,
    strength~,
  )
}

///|
test "upstream solver creation" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("unused")
  assert_eq(s.value(x), 0.0)
  assert_eq(s.statistics().constraints, 0)
  assert_eq(s.statistics().edits, 0)
}

///|
test "upstream managing constraints and exact errors" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let c1 = upstream_ge([(x, 1.0)], -1.0)
  let c2 = upstream_le([(x, 1.0)], 0.0)
  assert_false(s.has_constraint(c1))
  s.add_constraint(c1)
  assert_true(s.has_constraint(c1))
  try s.add_constraint(c1) catch {
    @cassowary.SolverError::DuplicateConstraint => ()
    _ => fail("expected exactly DuplicateConstraint")
  } noraise {
    _ => fail("missing DuplicateConstraint")
  }
  try s.remove_constraint(c2) catch {
    @cassowary.SolverError::UnknownConstraint => ()
    _ => fail("expected exactly UnknownConstraint")
  } noraise {
    _ => fail("missing UnknownConstraint")
  }
  try s.add_constraint(c2) catch {
    @cassowary.SolverError::UnsatisfiableConstraint => ()
    _ => fail("expected exactly UnsatisfiableConstraint")
  } noraise {
    _ => fail("missing UnsatisfiableConstraint")
  }
  assert_false(s.has_constraint(c2))
  assert_true(s.value(x) >= 1.0)
  s.remove_constraint(c1)
  assert_false(s.has_constraint(c1))
  s.add_constraint(c2)
  assert_true(s.has_constraint(c2))
  assert_true(s.value(x) <= 0.0)
  s.reset()
  assert_false(s.has_constraint(c2))
}

///|
test "upstream managing edit variables and exact errors" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let y = @cassowary.Variable::new("bar")
  assert_false(s.has_edit_variable(x))
  s.add_edit_variable(x, @cassowary.weak())
  assert_true(s.has_edit_variable(x))
  try s.add_edit_variable(x, @cassowary.medium()) catch {
    @cassowary.SolverError::DuplicateEditVariable => ()
    _ => fail("expected exactly DuplicateEditVariable")
  } noraise {
    _ => fail("missing DuplicateEditVariable")
  }
  try s.remove_edit_variable(y) catch {
    @cassowary.SolverError::UnknownEditVariable => ()
    _ => fail("expected exactly UnknownEditVariable")
  } noraise {
    _ => fail("missing UnknownEditVariable")
  }
  s.remove_edit_variable(x)
  assert_false(s.has_edit_variable(x))
  try s.add_edit_variable(x, @cassowary.required()) catch {
    @cassowary.SolverError::InvalidStrength => ()
    _ => fail("Kiwi BadRequiredStrength maps to InvalidStrength")
  } noraise {
    _ => fail("missing InvalidStrength")
  }
  s.add_edit_variable(y, @cassowary.strong())
  try s.suggest_value(x, 10.0) catch {
    @cassowary.SolverError::UnknownEditVariable => ()
    _ => fail("expected exactly UnknownEditVariable on suggest")
  } noraise {
    _ => fail("missing UnknownEditVariable on suggest")
  }
  s.reset()
  assert_false(s.has_edit_variable(y))
}

///|
test "upstream edit path weak equality and both delta signs" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  s.add_edit_variable(x, @cassowary.medium())
  s.add_constraint(upstream_eq([(x, 1.0)], -1.0, strength=@cassowary.weak()))
  s.suggest_value(x, 2.0)
  assert_eq(s.value(x), 2.0)
  // Exercise both edit error-symbol directions, not only an increasing delta.
  s.suggest_value(x, -3.0)
  assert_eq(s.value(x), -3.0)
  s.suggest_value(x, 7.0)
  assert_eq(s.value(x), 7.0)
}

///|
test "upstream edit path variable entering multiple rows" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let y = @cassowary.Variable::new("bar")
  s.add_edit_variable(y, @cassowary.weak())
  s.add_constraint(upstream_eq([(x, 1.0), (y, 1.0)], 0.0))
  s.add_constraint(upstream_le([(y, 1.0)], 1.0))
  s.add_constraint(upstream_ge([(y, 1.0)], 0.0, strength=@cassowary.weak()))
  s.suggest_value(y, 0.0)
  assert_true(s.value(y) <= -1.0)
  assert_eq(s.value(x) + s.value(y), 0.0)
}

///|
test "upstream under constrained system with edit" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let expression = @cassowary.Expression::new([(x, 2.0)], constant=1.0)
  let c = @cassowary.Constraint::new(
    expression,
    @cassowary.Relation::GreaterEqual,
  )
  s.add_edit_variable(x, @cassowary.weak())
  s.add_constraint(c)
  s.suggest_value(x, 10.0)
  assert_eq(s.value(x), 10.0)
  assert_eq(2.0 * s.value(x) + 1.0, 21.0)
  assert_eq(expression.value(s), 21.0)
}

///|
test "upstream underdetermined solutions compare feasibility not arbitrary values" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let y = @cassowary.Variable::new("y")
  s.add_constraint(upstream_eq([(x, 1.0), (y, 1.0)], -10.0))
  s.add_constraint(upstream_ge([(x, 1.0)], 0.0))
  s.add_constraint(upstream_ge([(y, 1.0)], 0.0))
  assert_eq(s.value(x) + s.value(y), 10.0)
  assert_true(s.value(x) >= 0.0)
  assert_true(s.value(y) >= 0.0)
  // Any point on this interval is valid; no tie-breaking contract is assumed.
}

///|
test "upstream solving with soft strengths" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let y = @cassowary.Variable::new("bar")
  s.add_constraint(upstream_eq([(x, 1.0), (y, 1.0)], 0.0))
  s.add_constraint(upstream_eq([(x, 1.0)], -10.0))
  s.add_constraint(upstream_ge([(y, 1.0)], 0.0, strength=@cassowary.weak()))
  assert_eq(s.value(x), 10.0)
  assert_eq(s.value(y), -10.0)
  s.reset()
  s.add_constraint(upstream_eq([(x, 1.0), (y, 1.0)], 0.0))
  s.add_constraint(upstream_ge([(x, 1.0)], -10.0, strength=@cassowary.medium()))
  s.add_constraint(upstream_eq([(y, 1.0)], -2.0, strength=@cassowary.strong()))
  assert_eq(s.value(x), -2.0)
  assert_eq(s.value(y), 2.0)
}

///|
test "upstream edit path infeasible rows dual optimization" {
  let s = @cassowary.Solver::new()
  let xm = @cassowary.Variable::new("xm")
  let xl = @cassowary.Variable::new("xl")
  let xr = @cassowary.Variable::new("xr")
  s.add_edit_variable(xm, @cassowary.strong())
  s.add_edit_variable(xl, @cassowary.weak())
  s.add_edit_variable(xr, @cassowary.weak())
  s.add_constraint(upstream_eq([(xm, 2.0), (xl, -1.0), (xr, -1.0)], 0.0))
  s.add_constraint(upstream_le([(xl, 1.0), (xr, -1.0)], 20.0))
  s.add_constraint(upstream_ge([(xl, 1.0)], 10.0))
  s.add_constraint(upstream_le([(xr, 1.0)], -100.0))
  s.suggest_value(xm, 40.0)
  s.suggest_value(xr, 50.0)
  s.suggest_value(xl, 30.0)
  s.suggest_value(xm, 60.0)
  s.suggest_value(xm, 90.0)
  assert_eq(s.value(xl) + s.value(xr), 2.0 * s.value(xm))
  assert_eq(s.value(xl), 80.0)
  assert_eq(s.value(xr), 100.0)
}

///|
test "upstream constraint violation includes independent raw residual" {
  let s = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("foo")
  let c1 = upstream_ge([(x, 1.0)], -10.0)
  let c2 = upstream_le([(x, 1.0)], 5.0, strength=@cassowary.weak())
  s.add_constraint(c1)
  s.add_constraint(c2)
  assert_true(s.value(x) >= 10.0)
  assert_eq(s.value(x) + 5.0, 15.0)
  assert_eq(c1.violation(s), 0.0)
  assert_eq(c2.violation(s), 15.0)
}
