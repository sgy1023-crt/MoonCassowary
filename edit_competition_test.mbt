// Edit suggestions minimize weighted L1 error, not last-write-wins.
// Compare hard residuals and objective values when several optima exist.

///|
test "compatible equal-strength suggestions are satisfied together" {
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
  solver.suggest_value(sidebar, 800.0)
  // Compatible suggestions determine a unique zero-error solution.
  assert_eq(solver.value(window), 800.0)
  assert_eq(solver.value(sidebar), 800.0)

  solver.suggest_value(sidebar, 300.0)
  // Any common value in [300, 800] minimizes the total edit error to 500.
  let value = solver.value(window)
  assert_true(value >= 300.0 && value <= 800.0)
  assert_eq(solver.value(sidebar), value)
  assert_eq((value - 800.0).abs() + (value - 300.0).abs(), 500.0)
  assert_true(solver.is_satisfied())

  solver.remove_edit_variable(sidebar)
  assert_true(!solver.has_edit_variable(sidebar))
  assert_eq(solver.value(window), 800.0)
  assert_eq(solver.value(sidebar), 800.0)
  // With the competing edit gone, the remaining suggestion takes over and the
  // equality carries both variables with it.
  solver.suggest_value(window, 520.0)
  assert_eq(solver.value(window), 520.0)
  assert_eq(solver.value(sidebar), 520.0)
  assert_true(solver.is_satisfied())
}

///|
test "conflicting equal-strength edits reach the same optimum in either order" {
  for reverse in [false, true] {
    let solver = @cassowary.Solver::new()
    let left = @cassowary.Variable::new("left")
    let right = @cassowary.Variable::new("right")
    solver.add_constraint(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(left, 1.0), (right, 1.0)], constant=-100.0),
        @cassowary.Relation::Equal,
      ),
    )
    let edits = if reverse {
      [(right, 40.0), (left, 30.0)]
    } else {
      [(left, 30.0), (right, 40.0)]
    }
    for (variable, _) in edits {
      solver.add_edit_variable(variable, @cassowary.strong())
    }
    for (variable, requested) in edits {
      solver.suggest_value(variable, requested)
    }
    let l = solver.value(left)
    let r = solver.value(right)
    assert_true((l + r - 100.0).abs() <= 1.0e-8)
    assert_true(((l - 30.0).abs() + (r - 40.0).abs() - 30.0).abs() <= 1.0e-8)
    assert_true(solver.is_satisfied())
    // Removing the left edit makes the right suggestion uniquely satisfiable.
    solver.remove_edit_variable(left)
    assert_eq(solver.value(left), 60.0)
    assert_eq(solver.value(right), 40.0)
    assert_true(solver.is_satisfied())
  }
}

///|
test "custom edit weights decide a conflict independently of suggestion order" {
  for reverse in [false, true] {
    let solver = @cassowary.Solver::new()
    let left = @cassowary.Variable::new("left")
    let right = @cassowary.Variable::new("right")
    solver.add_constraint(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(left, 1.0), (right, 1.0)], constant=-100.0),
        @cassowary.Relation::Equal,
      ),
    )
    solver.add_edit_variable(left, 2.0)
    solver.add_edit_variable(right, 1.0)
    let edits = if reverse {
      [(right, 40.0), (left, 30.0)]
    } else {
      [(left, 30.0), (right, 40.0)]
    }
    for (variable, requested) in edits {
      solver.suggest_value(variable, requested)
    }
    assert_eq(solver.value(left), 30.0)
    assert_eq(solver.value(right), 70.0)
    assert_true(solver.is_satisfied())
  }
}
