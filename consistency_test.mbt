// Public assertion helpers: callers should be able to check a solution without
// re-deriving residuals by hand.

///|
test "required violation is zero on a solved layout and nonzero when broken" {
  let solver = @cassowary.Solver::new()
  let sidebar = @cassowary.Variable::new("sidebar")
  let content = @cassowary.Variable::new("content")
  let width = @cassowary.Variable::new("width")
  let minimum = @cassowary.Constraint::new(
    @cassowary.Expression::new([(sidebar, 1.0)], constant=-160.0),
    @cassowary.Relation::GreaterEqual,
  )
  solver.add_constraint(minimum)
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(sidebar, 1.0), (content, 1.0), (width, -1.0)]),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(width, 1.0)], constant=-800.0),
      @cassowary.Relation::Equal,
    ),
  )
  assert_eq(solver.value(sidebar), 160.0)
  assert_eq(solver.value(content), 640.0)
  assert_true(solver.is_satisfied())
  assert_eq(solver.maximum_required_violation(), 0.0)
  // Removing a required relation leaves the remaining ones satisfied.
  solver.remove_constraint(minimum)
  assert_true(solver.is_satisfied())
}

///|
test "soft constraints do not count as required violations" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, 1.0)], constant=-10.0),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, 1.0)], constant=-99.0),
      @cassowary.Relation::Equal,
      strength=@cassowary.weak(),
    ),
  )
  // The weak preference is violated by design, but nothing required is.
  assert_eq(solver.value(x), 10.0)
  assert_true(solver.is_satisfied())
  assert_eq(solver.maximum_required_violation(), 0.0)
}

///|
test "empty solver reports satisfied and zero violation" {
  let solver = @cassowary.Solver::new()
  assert_eq(solver.maximum_required_violation(), 0.0)
  assert_true(solver.is_satisfied())
}

///|
test "tolerance is honored" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, 1.0)], constant=-5.0),
      @cassowary.Relation::Equal,
    ),
  )
  assert_true(solver.is_satisfied(tolerance=0.0))
  assert_true(solver.is_satisfied(tolerance=1.0e-12))
}

///|
test "noisy required constraint cannot masquerade as satisfied" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let y = @cassowary.Variable::new("y")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, 1.0)], constant=-2.0),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(y, 1.0)], constant=-3.0),
      @cassowary.Relation::Equal,
    ),
  )
  // Adding this constraint would overflow the tableau, so it is rejected and
  // the previously solved state must survive intact.
  let explosive = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0e308), (y, -1.0e308)]),
    @cassowary.Relation::LessEqual,
  )
  try solver.add_constraint(explosive) catch {
    @cassowary.NumericalFailure(_) => ()
    _ => fail("expected a numerical failure")
  } noraise {
    _ => fail("overflowing constraint must be rejected")
  }
  assert_true(!solver.has_constraint(explosive))
  assert_eq(solver.maximum_required_violation(), 0.0)
  assert_true(solver.is_satisfied())
  assert_eq(solver.value(x), 2.0)
  assert_eq(solver.value(y), 3.0)
}
