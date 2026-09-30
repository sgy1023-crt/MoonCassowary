///|
test "column benchmark actually honors feasible resizes and wraparound" {
  for count in [4, 8, 16] {
    let layout = build_columns(count)
    let minimum = count.to_double() * 40.0
    for step in [0, 1, 99, 100, 101] {
      let requested = requested_width(step, minimum, false)
      layout.solver.suggest_value(layout.width, requested)
      layout.check(requested)
    }
    assert_eq(layout.solver.statistics().constraints, count + 1)
    assert_eq(layout.solver.statistics().edits, 1)
  }
}

///|
test "column benchmark distinguishes clamping from feasible resizing" {
  for count in [4, 8, 16] {
    let layout = build_columns(count)
    let minimum = count.to_double() * 40.0
    for step in [0, 1, 99, 100] {
      layout.solver.suggest_value(
        layout.width,
        requested_width(step, minimum, true),
      )
      layout.check(minimum)
    }
    layout.solver.suggest_value(layout.width, 1300.0)
    layout.check(1300.0)
    layout.solver.suggest_value(layout.width, minimum - 1.0)
    layout.check(minimum)
  }
}
