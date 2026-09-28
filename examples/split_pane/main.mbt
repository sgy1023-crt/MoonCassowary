///|
fn run_split_pane() -> Unit raise {
  // These handles and this solver survive every resize and drag below.
  let solver = @cassowary.Solver::new()
  let width = @cassowary.Variable::new("window.width")
  let sidebar = @cassowary.Variable::new("sidebar.width")
  let content = @cassowary.Variable::new("content.width")
  let preview = @cassowary.Variable::new("preview.width")
  let toolbar = @cassowary.Variable::new("toolbar.marker")
  let fill = @cassowary.Constraint::new(
    @cassowary.Expression::new(
      [(sidebar, 1.0), (content, 1.0), (width, -1.0)],
      constant=16.0,
    ),
    @cassowary.Relation::Equal,
  )
  let sidebar_min = @cassowary.Constraint::new(
    @cassowary.Expression::new([(sidebar, 1.0)], constant=-160.0),
    @cassowary.Relation::GreaterEqual,
  )
  let content_min = @cassowary.Constraint::new(
    @cassowary.Expression::new([(content, 1.0)], constant=-320.0),
    @cassowary.Relation::GreaterEqual,
  )
  // Link independent nodes with a ratio, then align a third node to it.
  // No DOM, CSS, viewport runtime, or hand-calculated layout results.
  let ratio = @cassowary.Constraint::new(
    @cassowary.Expression::new([(preview, 2.0), (content, -1.0)]),
    @cassowary.Relation::Equal,
  )
  let alignment = @cassowary.Constraint::new(
    @cassowary.Expression::new(
      [(toolbar, 1.0), (sidebar, -1.0), (preview, -1.0)],
      constant=-16.0,
    ),
    @cassowary.Relation::Equal,
  )
  let required_constraints = [fill, sidebar_min, content_min, ratio, alignment]
  for variable in [width, sidebar, content, preview, toolbar] {
    required_constraints.push(
      @cassowary.Constraint::new(
        @cassowary.Expression::new([(variable, 1.0)]),
        @cassowary.Relation::GreaterEqual,
      ),
    )
  }
  for constraint in required_constraints {
    solver.add_constraint(constraint)
  }
  solver.add_edit_variable(width, @cassowary.strong())
  solver.add_edit_variable(sidebar, @cassowary.medium())
  println(
    "One incremental solver: strong window preference, medium sidebar preference.",
  )
  println(
    "Required: sidebar >= 160, content >= 320, gap = 16, all widths >= 0.",
  )
  println(
    "Cross-node links: preview = content / 2; toolbar marker = sidebar + gap + preview.",
  )
  println("suggest_value is a soft preference, NOT a direct assignment.")
  let steps : Array[(String, Double, Double)] = [
    ("initial", 960.0, 240.0),
    ("drag divider right", 960.0, 360.0),
    ("shrink window", 680.0, 360.0),
    ("drag below sidebar minimum", 680.0, 80.0),
    ("window narrower than required minimum", 400.0, 240.0),
    ("expand after narrow window", 1200.0, 280.0),
    ("drag beyond content minimum", 1200.0, 1000.0),
  ]
  let mut previous_pivots = solver.statistics().pivots
  for step in steps {
    let (label, requested_width, requested_sidebar) = step
    solver.suggest_value(width, requested_width)
    solver.suggest_value(sidebar, requested_sidebar)
    let actual_width = solver.value(width)
    let actual_sidebar = solver.value(sidebar)
    let actual_content = solver.value(content)
    let stats = solver.statistics()
    let mut max_residual = 0.0
    for constraint in required_constraints {
      let residual = constraint.violation(solver)
      if residual > max_residual {
        max_residual = residual
      }
      assert_true(residual < 0.000001)
    }
    assert_true(actual_sidebar >= 159.999999)
    assert_true(actual_content >= 319.999999)
    if requested_width < 496.0 {
      // Required minima can enlarge the solved window beyond the suggestion.
      assert_true(actual_width > requested_width)
    }
    println(
      "\n\{label}: suggest width=\{requested_width}, sidebar=\{requested_sidebar}",
    )
    println(
      "  solved width=\{actual_width}, sidebar=\{actual_sidebar}, content=\{actual_content}",
    )
    println(
      "  preview=\{solver.value(preview)}, toolbar.marker=\{solver.value(toolbar)}",
    )
    println(
      "  residuals: fill=\{fill.violation(solver)}, ratio=\{ratio.violation(solver)}, alignment=\{alignment.violation(solver)}, required.max=\{max_residual}",
    )
    println(
      "  preference deltas: width=\{actual_width - requested_width}, sidebar=\{actual_sidebar - requested_sidebar}",
    )
    println(
      "  pivots total=\{stats.pivots}, this step=\{stats.pivots - previous_pivots}; constraints=\{stats.constraints}, edits=\{stats.edits}",
    )
    previous_pivots = stats.pivots
  }
}

///|
fn main {
  run_split_pane() catch {
    error => {
      println("split_pane failed: \{error}")
      panic()
    }
  }
}
