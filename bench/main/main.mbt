// Measure edits on one persistent column layout, including correctness checks.
// This is not a speed comparison with Kiwi. Use --release for published runs.

///|
struct Columns {
  solver : @cassowary.Solver
  width : @cassowary.Variable
  columns : Array[@cassowary.Variable]
}

///|
/// The window is editable, not fixed by a required width equality.
fn build_columns(count : Int) -> Columns raise {
  assert_true(count > 0)
  let solver = @cassowary.Solver::new()
  let width = @cassowary.Variable::new("window")
  let columns = []
  let terms : Array[(@cassowary.Variable, Double)] = [(width, 1.0)]
  for index in 0..<count {
    let column = @cassowary.Variable::new("column\{index}")
    columns.push(column)
    terms.push((column, -1.0))
    solver.add_constraint(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(column, 1.0)], constant=-40.0),
        @cassowary.Relation::GreaterEqual,
      ),
    )
  }
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new(terms),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_edit_variable(width, @cassowary.strong())
  { solver, width, columns, }
}

///|
/// Check the actual solved window, column sum, minima and required residuals.
/// Individual columns are underdetermined; do not demand an arbitrary split.
fn Columns::check(self : Columns, expected : Double) -> Unit raise {
  assert_true((self.solver.value(self.width) - expected).abs() <= 1.0e-8)
  let mut total = 0.0
  for column in self.columns {
    let value = self.solver.value(column)
    assert_true(value >= 40.0 - 1.0e-8)
    total += value
  }
  assert_true((total - expected).abs() <= 1.0e-8)
  assert_true(self.solver.is_satisfied())
}

///|
fn requested_width(step : Int, minimum : Double, clamped : Bool) -> Double {
  let offset = (step % 100).to_double() * 0.5
  if clamped {
    minimum - 100.0 - offset
  } else {
    1200.0 + offset
  }
}

///|
fn run_sample(count : Int, clamped : Bool, sample : Int) -> Unit raise {
  let layout = build_columns(count)
  let minimum = count.to_double() * 40.0
  let scenario = if clamped { "clamped-minimum" } else { "feasible-resize" }
  let warmup = 128
  let steps = 2000
  for step in 0..<warmup {
    let requested = requested_width(step, minimum, clamped)
    layout.solver.suggest_value(layout.width, requested)
    layout.check(if clamped { minimum } else { requested })
  }
  let before = layout.solver.statistics()
  let start = @env.now()
  for step in 0..<steps {
    let requested = requested_width(step, minimum, clamped)
    layout.solver.suggest_value(layout.width, requested)
    layout.check(if clamped { minimum } else { requested })
  }
  let end = @env.now()
  // env.now() is Unix-epoch milliseconds, not a monotonic clock. Reject a
  // backwards clock before unsigned subtraction; never invent a zero-time rate.
  assert_true(end >= start)
  let elapsed = end - start
  let after = layout.solver.statistics()
  assert_eq(after.constraints, before.constraints)
  assert_eq(after.edits, before.edits)
  assert_eq(after.rows, before.rows)
  let label = "scenario=\{scenario} columns=\{count} sample=\{sample} warmup=\{warmup} steps=\{steps} elapsed_ms=\{elapsed} pivots=\{after.pivots - before.pivots}"
  if elapsed == 0 {
    println(
      "\{label} checked_edits_per_second=unavailable (timer resolution; increase steps)",
    )
  } else {
    let rate = steps.to_double() * 1000.0 / elapsed.to_double()
    println("\{label} checked_edits_per_second=\{rate}")
  }
}

///|
fn main raise {
  println(
    "MoonCassowary benchmark: setup/warmup excluded; per-edit validation included",
  )
  println(
    "clock=Unix-epoch milliseconds; use --release; no cross-library speed claim",
  )
  for count in [4, 8, 16] {
    for clamped in [false, true] {
      for sample in 1..<4 {
        run_sample(count, clamped, sample)
      }
    }
  }
}
