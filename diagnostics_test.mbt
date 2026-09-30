// Inspection helpers: a caller debugging a layout should be able to ask what a
// constraint is, not only whether it failed.

///|
test "relation, strength and required classification are readable" {
  let x = @cassowary.Variable::new("x")
  let expression = @cassowary.Expression::new([(x, 1.0)], constant=-1.0)
  let hard = @cassowary.Constraint::new(
    expression,
    @cassowary.Relation::GreaterEqual,
  )
  assert_eq(hard.relation(), @cassowary.Relation::GreaterEqual)
  assert_eq(hard.strength(), @cassowary.required())
  assert_true(hard.is_required())
  let soft = @cassowary.Constraint::new(
    expression,
    @cassowary.Relation::LessEqual,
    strength=@cassowary.weak(),
  )
  assert_eq(soft.relation(), @cassowary.Relation::LessEqual)
  assert_eq(soft.strength(), @cassowary.weak())
  assert_true(!soft.is_required())
}

///|
test "constraint rendering names variables, signs and the relation" {
  let x = @cassowary.Variable::new("width")
  let y = @cassowary.Variable::new("height")
  let equal = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0), (y, -2.0)], constant=-30.0),
    @cassowary.Relation::Equal,
  )
  let text = equal.to_repr()
  assert_true(text.contains("width"))
  assert_true(text.contains("height"))
  assert_true(text.contains("="))
  assert_true(text.contains("30"))
  let at_most = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=-100.0),
    @cassowary.Relation::LessEqual,
  )
  assert_true(at_most.to_repr().contains("<="))
}

///|
test "rendering a constant-only constraint is still readable" {
  let impossible = @cassowary.Constraint::new(
    @cassowary.Expression::new([]),
    @cassowary.Relation::Equal,
  )
  assert_true(impossible.to_repr().contains("="))
}

///|
test "diagnostics work after an unsatisfiable add is rejected" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let lower = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=-10.0),
    @cassowary.Relation::GreaterEqual,
  )
  let upper = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=-5.0),
    @cassowary.Relation::LessEqual,
  )
  solver.add_constraint(lower)
  try solver.add_constraint(upper) catch {
    @cassowary.UnsatisfiableConstraint => ()
    _ => fail("expected an unsatisfiable conflict")
  } noraise {
    _ => fail("expected the conflicting constraint to be rejected")
  }
  // The rejected constraint is still inspectable, and its violation explains
  // exactly why it could not be accepted: x is 10, the bound wants x <= 5.
  assert_true(upper.is_required())
  assert_eq(solver.value(x), 10.0)
  assert_eq(upper.violation(solver), 5.0)
  assert_true(upper.to_repr().contains("<="))
  // The accepted constraint is untouched and the solver stays usable.
  assert_eq(lower.violation(solver), 0.0)
  assert_true(solver.is_satisfied())
  assert_true(!solver.has_constraint(upper))
}
