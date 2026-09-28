// Regression tests for overflow handling and the mutable tableau primitives.

///|
test "residual evaluation cannot report NaN as zero violation" {
  let solver = Solver::new()
  let x = Variable::new("x")
  let y = Variable::new("y")
  solver.add_constraint(
    Constraint::new(Expression::new([(x, 1.0)], constant=-2.0), Equal),
  )
  solver.add_constraint(
    Constraint::new(Expression::new([(y, 1.0)], constant=-3.0), Equal),
  )
  for relation in [Equal, GreaterEqual, LessEqual] {
    let check = Constraint::new(
      Expression::new([(x, 1.0e308), (y, -1.0e308)]),
      relation,
    )
    try ignore(check.violation(solver)) catch {
      NumericalFailure(_) => ()
      _ => fail("expected a numerical failure")
    } noraise {
      _ => fail("overflow must be reported, never treated as satisfied")
    }
  }
  assert_eq(solver.value(x), 2.0)
  assert_eq(solver.value(y), 3.0)
}

///|
test "invalid expression evaluation is rejected even before addition" {
  let solver = Solver::new()
  let x = Variable::new("x")
  for
    expression in [
      Expression::new([], constant=@double.infinity),
      Expression::new([(x, @double.not_a_number)]),
    ] {
    try ignore(expression.value(solver)) catch {
      InvalidNumber => ()
      _ => fail("expected invalid number")
    } noraise {
      _ => fail("non-finite input must fail")
    }
  }
}

///|
test "overflow while adding a row restores the previous basis" {
  let solver = Solver::new()
  let x = Variable::new("x")
  solver.add_constraint(
    Constraint::new(Expression::new([(x, 1.0)], constant=-2.0), Equal),
  )
  let before = solver.statistics()
  let bad = Constraint::new(Expression::new([(x, 1.0e308)]), LessEqual)
  try solver.add_constraint(bad) catch {
    NumericalFailure(_) => ()
    _ => fail("expected a numerical failure")
  } noraise {
    _ => fail("tableau overflow must fail")
  }
  assert_eq(solver.statistics(), before)
  assert_true(!solver.has_constraint(bad))
  assert_eq(solver.value(x), 2.0)
}

///|
test "row cancellation drops a numerical zero" {
  let x = { id: 1, kind: External, }
  let row = Row::new(0.0)
  row.insert(x, 2.0)
  row.insert(x, -2.0)
  assert_true(row.cells.is_empty())
}

///|
test "row solve and substitute preserve the equation" {
  let x = { id: 1, kind: External, }
  let y = { id: 2, kind: External, }
  let row = Row::new(-10.0)
  row.insert(x, 2.0)
  row.insert(y, 1.0)
  row.solve_for(x)
  assert_eq(row.constant, 5.0)
  assert_eq(row.coefficient(y), -0.5)
  let y_row = Row::new(4.0)
  row.substitute(y, y_row)
  assert_eq(row.constant, 3.0)
  assert_true(row.cells.is_empty())
  assert_eq(y_row.constant, 4.0)
}

///|
test "row copy is independent" {
  let symbol = { id: 1, kind: Slack, }
  let row = Row::new(2.0)
  row.insert(symbol, 3.0)
  let copy = row.copy()
  copy.scale(-1.0)
  assert_eq(row.constant, 2.0)
  assert_eq(row.coefficient(symbol), 3.0)
  assert_eq(copy.coefficient(symbol), -3.0)
}

///|
test "pivot guard reports the limit instead of looping forever" {
  let state = Tableau::new()
  state.operation_pivots = 10000
  try state.count_pivot() catch {
    PivotLimit => ()
    _ => fail("expected pivot limit")
  } noraise {
    _ => fail("expected pivot limit")
  }
  assert_eq(state.pivots, 0)
}
