// Nested multi-panel layout driven by one persistent solver.
//
// Layout:                     window
//                +--------------+------------------+
//                |   sidebar    |  main            |
//                |              |  +----+--------+ |
//                |              |  |list| detail | |
//                |              |  +----+--------+ |
//                +--------------+------------------+
//
// Relationships a plain box model cannot express on its own:
//   - the sidebar keeps a soft 1:3 proportion against the main area,
//   - the mini list prefers a 40% share of the main area (soft),
//   - every panel has a hard minimum,
//   - dragging the sidebar is a suggestion, not an assignment.

///|
struct Panel {
  handle : @cassowary.Variable
  name : String
}

///|
fn report(
  solver : @cassowary.Solver,
  panels : Array[Panel],
  label : String,
) -> Unit raise {
  assert_true(solver.is_satisfied())
  let mut line = "\{label}: "
  for panel in panels {
    line += "\{panel.name}=\{solver.value(panel.handle)} "
  }
  let worst = solver.maximum_required_violation()
  println("\{line}| required.max=\{worst}")
}

///|
fn main raise {
  let solver = @cassowary.Solver::new()
  let window = @cassowary.Variable::new("window")
  let sidebar = @cassowary.Variable::new("sidebar")
  let main_area = @cassowary.Variable::new("main")
  let list = @cassowary.Variable::new("list")
  let detail = @cassowary.Variable::new("detail")
  let gap = 12.0
  let panels : Array[Panel] = [
    { handle: window, name: "window", },
    { handle: sidebar, name: "sidebar", },
    { handle: main_area, name: "main", },
    { handle: list, name: "list", },
    { handle: detail, name: "detail", },
  ]

  // Hard structure: window = sidebar + gap + main, main = list + detail.
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new(
        [(window, 1.0), (sidebar, -1.0), (main_area, -1.0)],
        constant=-gap,
      ),
      @cassowary.Relation::Equal,
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([
        (main_area, 1.0),
        (list, -1.0),
        (detail, -1.0),
      ]),
      @cassowary.Relation::Equal,
    ),
  )

  // Hard minimums.
  for
    (variable, minimum) in [
      (sidebar, 180.0),
      (main_area, 420.0),
      (list, 120.0),
      (detail, 200.0),
    ] {
    solver.add_constraint(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(variable, 1.0)], constant=-minimum),
        @cassowary.Relation::GreaterEqual,
      ),
    )
  }

  // Soft relationships: 1:3 sidebar/main proportion and a 40% list share.
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(sidebar, 3.0), (main_area, -1.0)]),
      @cassowary.Relation::Equal,
      strength=@cassowary.medium(),
    ),
  )
  solver.add_constraint(
    @cassowary.Constraint::new(
      @cassowary.Expression::new([(list, 5.0), (main_area, -2.0)]),
      @cassowary.Relation::Equal,
      strength=@cassowary.strong(),
    ),
  )

  // Both edit handles can be satisfied when sufficient space remains. Equal
  // strengths do not define write ordering when suggestions are incompatible.
  solver.add_edit_variable(window, @cassowary.strong())
  solver.add_edit_variable(sidebar, @cassowary.strong())
  solver.suggest_value(window, 1280.0)
  assert_eq(solver.value(window), 1280.0)
  report(solver, panels, "open at 1280")

  // A window resize keeps every required relationship, including nested ones.
  solver.suggest_value(window, 1024.0)
  assert_eq(solver.value(window), 1024.0)
  report(solver, panels, "resize to 1024")

  // The compatible drag and window suggestions outweigh the medium proportion.
  solver.suggest_value(sidebar, 500.0)
  assert_eq(solver.value(window), 1024.0)
  assert_eq(solver.value(sidebar), 500.0)
  assert_eq(solver.value(main_area), 512.0)
  assert_true((solver.value(list) - 204.8).abs() <= 1.0e-8)
  assert_true((solver.value(detail) - 307.2).abs() <= 1.0e-8)
  report(solver, panels, "drag sidebar to 500")

  // A window narrower than the required minimums cannot be honored. Check the
  // hard bounds and minimum combined edit error, not an arbitrary tied optimum.
  solver.suggest_value(window, 300.0)
  solver.suggest_value(sidebar, 200.0)
  assert_true(solver.value(window) >= 612.0 - 1.0e-8)
  let edit_error = (solver.value(window) - 300.0).abs() +
    (solver.value(sidebar) - 200.0).abs()
  assert_true((edit_error - 332.0).abs() <= 1.0e-8)
  report(solver, panels, "shrink to 300")
  println("(the suggested width is a preference; required minimums win)")
  println("all required relationships hold: true (asserted at every step)")
}
