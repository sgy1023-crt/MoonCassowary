///|
fn behavior_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(
    actual > expected - 0.000001 && actual < expected + 0.000001,
    msg="expected \{expected}, got \{actual}",
  )
}

///|
fn behavior_equal(
  variable : @cassowary.Variable,
  value : Double,
  strength? : Double = 1001001000.0,
) -> @cassowary.Constraint {
  @cassowary.Constraint::new(
    @cassowary.Expression::new([(variable, 1.0)], constant=-value),
    @cassowary.Relation::Equal,
    strength~,
  )
}

///|
fn behavior_expect_error(
  expected : @cassowary.SolverError,
  operation : () -> Unit raise @cassowary.SolverError,
) -> Unit raise {
  let result : Result[Unit, @cassowary.SolverError] = try {
    operation()
    Ok(())
  } catch {
    error => Err(error)
  }
  match result {
    Ok(_) => fail("expected a SolverError, but the operation succeeded")
    Err(actual) => assert_true(actual == expected)
  }
}

///|
test "behavior: same name is not variable identity" {
  let solver = @cassowary.Solver::new()
  let left = @cassowary.Variable::new("same-name")
  let right = @cassowary.Variable::new("same-name")
  let unknown = @cassowary.Variable::new("same-name")
  solver.add_constraint(behavior_equal(left, 3.0))
  solver.add_constraint(behavior_equal(right, 8.0))
  behavior_close(solver.value(left), 3.0)
  behavior_close(solver.value(right), 8.0)
  behavior_close(solver.value(unknown), 0.0)
  assert_true(!solver.has_edit_variable(unknown))
}

///|
test "behavior: one variable has independent values in two solvers" {
  let left = @cassowary.Solver::new()
  let right = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("shared-handle")
  left.add_edit_variable(x, @cassowary.strong())
  right.add_edit_variable(x, @cassowary.strong())
  left.suggest_value(x, 12.0)
  right.suggest_value(x, -9.0)
  behavior_close(left.value(x), 12.0)
  behavior_close(right.value(x), -9.0)
  left.suggest_value(x, 21.0)
  behavior_close(right.value(x), -9.0)
  let expression = @cassowary.Expression::new([(x, 2.0)], constant=1.0)
  behavior_close(expression.value(left), 43.0)
  behavior_close(expression.value(right), -17.0)
  left.reset()
  behavior_close(left.value(x), 0.0)
  behavior_close(right.value(x), -9.0)
  assert_true(right.has_edit_variable(x))
}

///|
test "behavior: constraint membership is solver local" {
  let left = @cassowary.Solver::new()
  let right = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let constraint = behavior_equal(x, 6.0)
  left.add_constraint(constraint)
  assert_true(!right.has_constraint(constraint))
  right.add_constraint(constraint)
  left.remove_constraint(constraint)
  assert_true(!left.has_constraint(constraint))
  assert_true(right.has_constraint(constraint))
  behavior_close(right.value(x), 6.0)
}

///|
test "behavior: duplicate constraint rejects without losing the original" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let constraint = behavior_equal(x, 7.0)
  solver.add_constraint(constraint)
  behavior_expect_error(@cassowary.SolverError::DuplicateConstraint, fn() raise @cassowary.SolverError {
    solver.add_constraint(constraint)
  })
  assert_true(solver.has_constraint(constraint))
  assert_eq(solver.statistics().constraints, 1)
  behavior_close(solver.value(x), 7.0)
  solver.remove_constraint(constraint)
  solver.add_constraint(constraint)
  behavior_close(solver.value(x), 7.0)
}

///|
test "behavior: unknown removal uses identity not expression equality" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let original = behavior_equal(x, 7.0)
  let lookalike = behavior_equal(x, 7.0)
  solver.add_constraint(original)
  behavior_expect_error(@cassowary.SolverError::UnknownConstraint, fn() raise @cassowary.SolverError {
    solver.remove_constraint(lookalike)
  })
  behavior_close(solver.value(x), 7.0)
  assert_true(solver.has_constraint(original))
  assert_true(!solver.has_constraint(lookalike))
  solver.remove_constraint(original)
  behavior_expect_error(@cassowary.SolverError::UnknownConstraint, fn() raise @cassowary.SolverError {
    solver.remove_constraint(original)
  })
  solver.add_constraint(lookalike)
  behavior_close(solver.value(x), 7.0)
}

///|
test "behavior: equivalent distinct constraints are removable redundancy" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let first = behavior_equal(x, 7.0)
  let second = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 2.0)], constant=-14.0),
    @cassowary.Relation::Equal,
  )
  solver.add_constraint(first)
  solver.add_constraint(second)
  assert_eq(solver.statistics().constraints, 2)
  solver.remove_constraint(first)
  assert_true(solver.has_constraint(second))
  behavior_close(solver.value(x), 7.0)
  solver.remove_constraint(second)
  solver.add_constraint(behavior_equal(x, 11.0))
  behavior_close(solver.value(x), 11.0)
}

///|
test "behavior: hard conflict leaves the solver editable and removable" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let y = @cassowary.Variable::new("y")
  let link = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0), (y, 1.0)], constant=-10.0),
    @cassowary.Relation::Equal,
  )
  let anchor = behavior_equal(x, 4.0)
  let conflict = behavior_equal(x, 8.0)
  solver.add_constraint(link)
  solver.add_constraint(anchor)
  solver.add_edit_variable(y, @cassowary.strong())
  solver.suggest_value(y, 6.0)
  behavior_expect_error(@cassowary.SolverError::UnsatisfiableConstraint, fn() raise @cassowary.SolverError {
    solver.add_constraint(conflict)
  })
  assert_true(!solver.has_constraint(conflict))
  assert_eq(solver.statistics().constraints, 2)
  assert_eq(solver.statistics().edits, 1)
  behavior_close(solver.value(x), 4.0)
  behavior_close(solver.value(y), 6.0)
  solver.remove_constraint(anchor)
  solver.suggest_value(y, 3.0)
  behavior_close(solver.value(x), 7.0)
  behavior_close(solver.value(y), 3.0)
  solver.add_constraint(conflict)
  behavior_close(solver.value(x), 8.0)
  behavior_close(solver.value(y), 2.0)
  behavior_close(link.violation(solver), 0.0)
}

///|
test "behavior: rejected inequality does not poison subsequent dual edits" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let lower = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)]),
    @cassowary.Relation::GreaterEqual,
  )
  let impossible = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=1.0),
    @cassowary.Relation::LessEqual,
  )
  solver.add_constraint(lower)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 12.0)
  for _ in 0..<3 {
    behavior_expect_error(@cassowary.SolverError::UnsatisfiableConstraint, fn() raise @cassowary.SolverError {
      solver.add_constraint(impossible)
    })
    assert_true(!solver.has_constraint(impossible))
    behavior_close(solver.value(x), 12.0)
  }
  solver.suggest_value(x, -8.0)
  behavior_close(solver.value(x), 0.0)
  solver.suggest_value(x, 15.0)
  behavior_close(solver.value(x), 15.0)
  solver.remove_constraint(lower)
  solver.add_constraint(impossible)
  solver.suggest_value(x, -8.0)
  behavior_close(solver.value(x), -8.0)
}

///|
test "behavior: required strength cannot be registered as an edit" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  behavior_expect_error(@cassowary.SolverError::InvalidStrength, fn() raise @cassowary.SolverError {
    solver.add_edit_variable(x, @cassowary.required())
  })
  assert_true(!solver.has_edit_variable(x))
  assert_eq(solver.statistics().edits, 0)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 5.0)
  behavior_close(solver.value(x), 5.0)
}

///|
test "behavior: duplicate edit preserves its existing state" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 5.0)
  behavior_expect_error(@cassowary.SolverError::DuplicateEditVariable, fn() raise @cassowary.SolverError {
    solver.add_edit_variable(x, @cassowary.weak())
  })
  assert_true(solver.has_edit_variable(x))
  assert_eq(solver.statistics().edits, 1)
  behavior_close(solver.value(x), 5.0)
  solver.suggest_value(x, 9.0)
  behavior_close(solver.value(x), 9.0)
  solver.remove_edit_variable(x)
  solver.add_edit_variable(x, @cassowary.medium())
  solver.suggest_value(x, -3.0)
  behavior_close(solver.value(x), -3.0)
}

///|
test "behavior: unknown edit suggestion and removal do not register edits" {
  let solver = @cassowary.Solver::new()
  let known = @cassowary.Variable::new("same-name")
  let unknown = @cassowary.Variable::new("same-name")
  solver.add_edit_variable(known, @cassowary.strong())
  solver.suggest_value(known, 4.0)
  behavior_expect_error(@cassowary.SolverError::UnknownEditVariable, fn() raise @cassowary.SolverError {
    solver.suggest_value(unknown, 6.0)
  })
  behavior_expect_error(@cassowary.SolverError::UnknownEditVariable, fn() raise @cassowary.SolverError {
    solver.remove_edit_variable(unknown)
  })
  assert_true(!solver.has_edit_variable(unknown))
  behavior_close(solver.value(known), 4.0)
  solver.remove_edit_variable(known)
  behavior_expect_error(@cassowary.SolverError::UnknownEditVariable, fn() raise @cassowary.SolverError {
    solver.suggest_value(known, 8.0)
  })
  behavior_expect_error(@cassowary.SolverError::UnknownEditVariable, fn() raise @cassowary.SolverError {
    solver.remove_edit_variable(known)
  })
  solver.add_edit_variable(known, @cassowary.strong())
  solver.suggest_value(known, 8.0)
  behavior_close(solver.value(known), 8.0)
}

///|
test "behavior: reset clears membership and allows all handles to be reused" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let constraint = behavior_equal(x, 4.0)
  solver.add_constraint(constraint)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 9.0)
  solver.reset()
  assert_true(!solver.has_constraint(constraint))
  assert_true(!solver.has_edit_variable(x))
  behavior_close(solver.value(x), 0.0)
  let empty = solver.statistics()
  assert_eq(empty.constraints, 0)
  assert_eq(empty.edits, 0)
  assert_eq(empty.variables, 0)
  assert_eq(empty.rows, 0)
  assert_eq(empty.pivots, 0)
  behavior_expect_error(@cassowary.SolverError::UnknownConstraint, fn() raise @cassowary.SolverError {
    solver.remove_constraint(constraint)
  })
  solver.add_constraint(constraint)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 9.0)
  behavior_close(solver.value(x), 4.0)
  solver.remove_constraint(constraint)
  behavior_close(solver.value(x), 9.0)
  solver.reset()
  solver.reset()
  solver.add_edit_variable(x, @cassowary.medium())
  solver.suggest_value(x, -2.0)
  behavior_close(solver.value(x), -2.0)
}

///|
test "behavior: zero-term constant tautologies add and remove normally" {
  let solver = @cassowary.Solver::new()
  let tautologies = [
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=0.0),
      @cassowary.Relation::Equal,
    ),
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=-2.0),
      @cassowary.Relation::LessEqual,
    ),
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=3.0),
      @cassowary.Relation::GreaterEqual,
    ),
  ]
  for constraint in tautologies {
    solver.add_constraint(constraint)
    behavior_close(constraint.violation(solver), 0.0)
  }
  assert_eq(solver.statistics().constraints, 3)
  for constraint in tautologies {
    solver.remove_constraint(constraint)
    assert_true(!solver.has_constraint(constraint))
  }
  assert_eq(solver.statistics().constraints, 0)
}

///|
test "behavior: zero-term hard contradictions fail without blocking later adds" {
  let solver = @cassowary.Solver::new()
  let contradictions = [
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=1.0),
      @cassowary.Relation::Equal,
    ),
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=1.0),
      @cassowary.Relation::LessEqual,
    ),
    @cassowary.Constraint::new(
      @cassowary.Expression::new([], constant=-1.0),
      @cassowary.Relation::GreaterEqual,
    ),
  ]
  for constraint in contradictions {
    behavior_expect_error(@cassowary.SolverError::UnsatisfiableConstraint, fn() raise @cassowary.SolverError {
      solver.add_constraint(constraint)
    })
    assert_true(!solver.has_constraint(constraint))
    assert_eq(solver.statistics().constraints, 0)
  }
  let x = @cassowary.Variable::new("x")
  solver.add_constraint(behavior_equal(x, 13.0))
  behavior_close(solver.value(x), 13.0)
}

///|
test "behavior: cancelled coefficients expose a constant contradiction" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let constraint = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0), (x, -1.0)], constant=1.0),
    @cassowary.Relation::Equal,
  )
  behavior_expect_error(@cassowary.SolverError::UnsatisfiableConstraint, fn() raise @cassowary.SolverError {
    solver.add_constraint(constraint)
  })
  solver.add_constraint(behavior_equal(x, 2.0))
  behavior_close(solver.value(x), 2.0)
}

///|
test "behavior: a constant soft violation is allowed and independently measurable" {
  let solver = @cassowary.Solver::new()
  let constant = @cassowary.Constraint::new(
    @cassowary.Expression::new([], constant=7.0),
    @cassowary.Relation::Equal,
    strength=@cassowary.weak(),
  )
  solver.add_constraint(constant)
  assert_true(solver.has_constraint(constant))
  behavior_close(constant.violation(solver), 7.0)
  solver.remove_constraint(constant)
  assert_eq(solver.statistics().constraints, 0)
}

///|
test "behavior: unequal soft weights select the stronger preference then recover" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let light = behavior_equal(x, 0.0, strength=@cassowary.weak())
  let heavy = behavior_equal(x, 100.0, strength=2.0 * @cassowary.weak())
  solver.add_constraint(light)
  solver.add_constraint(heavy)
  behavior_close(solver.value(x), 100.0)
  behavior_close(light.violation(solver), 100.0)
  behavior_close(heavy.violation(solver), 0.0)
  solver.remove_constraint(heavy)
  behavior_close(solver.value(x), 0.0)
  solver.add_constraint(heavy)
  behavior_close(solver.value(x), 100.0)
}

///|
test "behavior: soft weights accumulate rather than forming absolute priority levels" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let one = behavior_equal(x, 100.0, strength=2.0)
  solver.add_constraint(one)
  let preferences = [
    behavior_equal(x, 0.0, strength=1.0),
    behavior_equal(x, 0.0, strength=1.0),
    behavior_equal(x, 0.0, strength=1.0),
  ]
  for preference in preferences {
    solver.add_constraint(preference)
  }
  behavior_close(solver.value(x), 0.0)
  for preference in preferences {
    solver.remove_constraint(preference)
  }
  behavior_close(solver.value(x), 100.0)
}

///|
test "behavior: invalid finite strength leaves existing constraints unchanged" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  let valid = behavior_equal(x, 3.0)
  let invalid = behavior_equal(x, 9.0, strength=-1.0)
  solver.add_constraint(valid)
  behavior_expect_error(@cassowary.SolverError::InvalidStrength, fn() raise @cassowary.SolverError {
    solver.add_constraint(invalid)
  })
  behavior_expect_error(@cassowary.SolverError::InvalidStrength, fn() raise @cassowary.SolverError {
    solver.add_edit_variable(x, -1.0)
  })
  assert_true(!solver.has_constraint(invalid))
  assert_true(!solver.has_edit_variable(x))
  behavior_close(solver.value(x), 3.0)
  solver.remove_constraint(valid)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 9.0)
  behavior_close(solver.value(x), 9.0)
}

///|
fn behavior_nonfinite(numerator : Double) -> Double {
  numerator / 0.0
}

///|
test "behavior: nonfinite coefficients and constants are rejected atomically" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 4.0)
  for
    number in [
      behavior_nonfinite(0.0),
      behavior_nonfinite(1.0),
      behavior_nonfinite(-1.0),
    ] {
    let bad_coefficient = @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, number)]),
      @cassowary.Relation::Equal,
    )
    let bad_constant = @cassowary.Constraint::new(
      @cassowary.Expression::new([(x, 1.0)], constant=number),
      @cassowary.Relation::Equal,
    )
    for constraint in [bad_coefficient, bad_constant] {
      behavior_expect_error(@cassowary.SolverError::InvalidNumber, fn() raise @cassowary.SolverError {
        solver.add_constraint(constraint)
      })
      assert_true(!solver.has_constraint(constraint))
      behavior_close(solver.value(x), 4.0)
      assert_eq(solver.statistics().constraints, 0)
    }
  }
  solver.suggest_value(x, 8.0)
  behavior_close(solver.value(x), 8.0)
}

///|
test "behavior: nonfinite suggestions preserve the last valid edit delta" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 4.0)
  for
    number in [
      behavior_nonfinite(0.0),
      behavior_nonfinite(1.0),
      behavior_nonfinite(-1.0),
    ] {
    behavior_expect_error(@cassowary.SolverError::InvalidNumber, fn() raise @cassowary.SolverError {
      solver.suggest_value(x, number)
    })
    behavior_close(solver.value(x), 4.0)
  }
  solver.suggest_value(x, -6.0)
  behavior_close(solver.value(x), -6.0)
  solver.remove_edit_variable(x)
  solver.add_edit_variable(x, @cassowary.medium())
  solver.suggest_value(x, 2.0)
  behavior_close(solver.value(x), 2.0)
}

///|
test "behavior: nonfinite strengths never register constraints or edits" {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("x")
  for
    strength in [
      behavior_nonfinite(0.0),
      behavior_nonfinite(1.0),
      behavior_nonfinite(-1.0),
    ] {
    let constraint = behavior_equal(x, 7.0, strength~)
    behavior_expect_error(@cassowary.SolverError::InvalidStrength, fn() raise @cassowary.SolverError {
      solver.add_constraint(constraint)
    })
    behavior_expect_error(@cassowary.SolverError::InvalidStrength, fn() raise @cassowary.SolverError {
      solver.add_edit_variable(x, strength)
    })
    assert_true(!solver.has_constraint(constraint))
    assert_true(!solver.has_edit_variable(x))
  }
  solver.add_constraint(behavior_equal(x, 7.0))
  behavior_close(solver.value(x), 7.0)
}
