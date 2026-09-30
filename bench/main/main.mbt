// Repeatable benchmark for the incremental update path.
//
// Prints machine-readable numbers so a reviewer can rerun the same command.
// These are measurements of THIS implementation on the machine that ran them:
// they are not a claim that it matches or beats Kiwi's speed.

///|
fn stats_line(label : String, solver : @cassowary.Solver) -> Unit {
  let stats = solver.statistics()
  println(
    "\{label}: constraints=\{stats.constraints} rows=\{stats.rows} pivots=\{stats.pivots}",
  )
}

///|
/// Build a column layout: one soft-preference edit for the window width, one
/// required sum relation, and a required minimum for every column.
fn build_columns(
  window_width : Double,
  columns : Int,
) -> (@cassowary.Solver, @cassowary.Variable) raise @cassowary.SolverError {
  let solver = @cassowary.Solver::new()
  let width = @cassowary.Variable::new("window")
  let terms : Array[(@cassowary.Variable, Double)] = [(width, 1.0)]
  let mut index = 0
  while index < columns {
    let column = @cassowary.Variable::new("column\{index}")
    terms.push((column, -1.0))
    solver.add_constraint(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(column, 1.0)], constant=-40.0),
        @cassowary.Relation::GreaterEqual,
      ),
    )
    index += 1
  }
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new(terms),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(width, 1.0)], constant=-window_width),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_edit_variable(width, @cassowary.strong())
  (solver, width)
}

///|
/// Edits per second over `steps` successive suggestions, after one warm-up.
fn edits_per_second(
  columns : Int,
  steps : Int,
) -> Double raise @cassowary.SolverError {
  let (solver, width) = build_columns(1200.0, columns)
  solver.suggest_value(width, 1200.0)
  let start = @env.now()
  let mut step = 0
  while step < steps {
    solver.suggest_value(width, 1200.0 + step.to_double() * 0.5)
    step += 1
  }
  let elapsed = @env.now() - start
  let seconds = elapsed.to_double() / 1000.0
  if seconds <= 0.0 {
    steps.to_double()
  } else {
    steps.to_double() / seconds
  }
}

///|
fn main {
  println("MoonCassowary benchmark: single run, not a comparison claim")
  for columns in [4, 8, 16] {
    let (solver, _) = build_columns(1200.0, columns) catch {
      error => {
        println("columns=\{columns}: setup failed: \{@debug.to_string(error)}")
        continue
      }
    }
    stats_line("columns=\{columns}", solver)
  }
  for columns in [4, 8, 16] {
    let rate = edits_per_second(columns, 2000) catch { _ => 0.0 }
    println("columns=\{columns}: \{rate.to_int()} edits/second over 2000 steps")
  }
}
