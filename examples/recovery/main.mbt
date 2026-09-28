///|
fn run_recovery() -> Unit raise {
  let solver = @cassowary.Solver::new()
  let x = @cassowary.Variable::new("position")
  let minimum = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)]),
    @cassowary.Relation::GreaterEqual,
  )
  let maximum = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=-100.0),
    @cassowary.Relation::LessEqual,
  )
  solver.add_constraint(minimum)
  solver.add_constraint(maximum)
  solver.add_edit_variable(x, @cassowary.strong())
  solver.suggest_value(x, 40.0)
  println("Before conflict: position=\{solver.value(x)}")
  let conflict = @cassowary.Constraint::new(
    @cassowary.Expression::new([(x, 1.0)], constant=10.0),
    @cassowary.Relation::LessEqual,
  )
  let rejected = try {
    solver.add_constraint(conflict)
    false
  } catch {
    @cassowary.SolverError::UnsatisfiableConstraint => {
      println(
        "Caught UnsatisfiableConstraint: position <= -10 conflicts with position >= 0.",
      )
      true
    }
    error => raise error
  }
  assert_true(rejected)
  assert_true(!solver.has_constraint(conflict))
  assert_true(solver.has_constraint(minimum))
  assert_true(solver.value(x) > 39.999999 && solver.value(x) < 40.000001)
  solver.suggest_value(x, 80.0)
  assert_true(solver.value(x) > 79.999999 && solver.value(x) < 80.000001)
  println("Same solver, next edit: position=\{solver.value(x)}")
  solver.remove_constraint(maximum)
  solver.suggest_value(x, 140.0)
  assert_true(solver.value(x) > 139.999999 && solver.value(x) < 140.000001)
  assert_true(minimum.violation(solver) < 0.000001)
  println("Removed upper bound, edited again: position=\{solver.value(x)}")
  solver.remove_edit_variable(x)
  solver.remove_constraint(minimum)
  assert_true(!solver.has_edit_variable(x))
  assert_true(!solver.has_constraint(minimum))
  let stats = solver.statistics()
  println(
    "Cleaned up: constraints=\{stats.constraints}, edits=\{stats.edits}, pivots=\{stats.pivots}",
  )
}

///|
fn main {
  run_recovery() catch {
    error => {
      println("recovery failed: \{error}")
      panic()
    }
  }
}
