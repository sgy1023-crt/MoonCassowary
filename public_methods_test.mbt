// Public derived methods must remain explicit across MoonBit toolchain updates.

///|
test "derived methods remain usable as public methods" {
  let x = @cassowary.Variable::new("x")
  let other = @cassowary.Variable::new("x")
  assert_true(x.equal(x))
  assert_true(x.not_equal(other))
  assert_eq(x.hash(), x.hash())
  ignore(x.to_repr())
  let relation = @cassowary.Relation::Equal
  assert_true(relation.equal(@cassowary.Relation::Equal))
  ignore(relation.to_repr())
  let error = @cassowary.SolverError::InvalidNumber
  assert_true(error.equal(@cassowary.SolverError::InvalidNumber))
  ignore(error.to_repr())
  let stats = @cassowary.Solver::new().statistics()
  assert_true(stats.equal(stats))
  ignore(stats.to_repr())
}
