///|
fn solve_equations() -> Unit raise {
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
  assert_true(solver.value(x) > 6.999999 && solver.value(x) < 7.000001)
  assert_true(solver.value(y) > 2.999999 && solver.value(y) < 3.000001)
  assert_true(sum.violation(solver) < 0.000001)
  assert_true(difference.violation(solver) < 0.000001)
  println("x + y = 10; x - y = 4")
  println("Solved: x=\{solver.value(x)}, y=\{solver.value(y)}")
  println(
    "Residuals: sum=\{sum.violation(solver)}, difference=\{difference.violation(solver)}",
  )
  println("Pivots: \{solver.statistics().pivots}")
}

///|
fn main {
  solve_equations() catch {
    error => {
      println("equations failed: \{error}")
      panic()
    }
  }
}
