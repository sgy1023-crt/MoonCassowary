// Two edit variables competing for the same space.
//
// These expectations were established against Kiwi 1.4.9 (the fixed upstream
// revision) because the behavior is subtle: an equal-strength suggestion does
// not necessarily displace an edit that is already holding a value.

///|
test "equal-strength suggestions let the latest one win when both are free" {
  let solver = @cassowary.Solver::new()
  let window = @cassowary.Variable::new("window")
  let sidebar = @cassowary.Variable::new("sidebar")
  let main_area = @cassowary.Variable::new("main")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new(
        [(window, 1.0), (sidebar, -1.0), (main_area, -1.0)],
        constant=-12.0,
      ),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(sidebar, 1.0)], constant=-180.0),
      @cassowary.Relation::GreaterEqual,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(main_area, 1.0)], constant=-420.0),
      @cassowary.Relation::GreaterEqual,
    ),
  )
  solver.add_edit_variable(window, @cassowary.strong())
  solver.add_edit_variable(sidebar, @cassowary.strong())

  solver.suggest_value(window, 1280.0)
  assert_eq(solver.value(window), 1280.0)
  assert_eq(solver.value(sidebar), 180.0)

  solver.suggest_value(sidebar, 500.0)
  assert_eq(solver.value(sidebar), 500.0)
  assert_eq(solver.value(main_area), 768.0)
  // The window suggestion holds; dragging the divider must not stretch it.
  assert_eq(solver.value(window), 1280.0)
  assert_true(solver.is_satisfied())
}

///|
test "a later suggestion cannot break a required minimum" {
  let solver = @cassowary.Solver::new()
  let sidebar = @cassowary.Variable::new("sidebar")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(sidebar, 1.0)], constant=-180.0),
      @cassowary.Relation::GreaterEqual,
    ),
  )
  solver.add_edit_variable(sidebar, @cassowary.strong())
  solver.suggest_value(sidebar, 40.0)
  // The required minimum wins over the suggestion.
  assert_eq(solver.value(sidebar), 180.0)
  assert_true(solver.is_satisfied())
}

///|
test "a weaker suggestion does not displace a stronger edit variable" {
  let solver = @cassowary.Solver::new()
  let left = @cassowary.Variable::new("left")
  let right = @cassowary.Variable::new("right")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(left, 1.0), (right, 1.0)], constant=-100.0),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_edit_variable(left, @cassowary.strong())
  solver.suggest_value(left, 30.0)
  assert_eq(solver.value(left), 30.0)
  assert_eq(solver.value(right), 70.0)

  // A weaker suggestion on the other variable cannot outrank the strong edit.
  solver.add_edit_variable(right, @cassowary.weak())
  solver.suggest_value(right, 5.0)
  assert_eq(solver.value(right), 70.0)
  assert_eq(solver.value(left), 30.0)
}

///|
test "removing one competing edit variable releases the other" {
  let solver = @cassowary.Solver::new()
  let window = @cassowary.Variable::new("window")
  let sidebar = @cassowary.Variable::new("sidebar")
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(window, 1.0), (sidebar, -1.0)]),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_edit_variable(window, @cassowary.strong())
  solver.add_edit_variable(sidebar, @cassowary.strong())
  solver.suggest_value(window, 800.0)
  // The equality ties both variables to the same value.
  assert_eq(solver.value(window), 800.0)
  assert_eq(solver.value(sidebar), 800.0)

  // An equal-strength suggestion on the already-satisfied peer does not move
  // anything; this matches Kiwi 1.4.9 exactly.
  solver.suggest_value(sidebar, 300.0)
  assert_eq(solver.value(sidebar), 800.0)
  assert_eq(solver.value(window), 800.0)

  solver.remove_edit_variable(sidebar)
  assert_true(!solver.has_edit_variable(sidebar))
  // With the competing edit gone, the remaining suggestion takes over and the
  // equality carries both variables with it.
  solver.suggest_value(window, 520.0)
  assert_eq(solver.value(window), 520.0)
  assert_eq(solver.value(sidebar), 520.0)
  assert_true(solver.is_satisfied())
}
