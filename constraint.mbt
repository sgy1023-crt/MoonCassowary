// Kiwi 1.4.9 port: Copyright (c) 2013-2025, Nucleic Development Team.
// MoonBit adaptation: Copyright (c) 2026, MoonCassowary contributors.
// Distributed under BSD-3-Clause; see LICENSE and THIRD_PARTY_NOTICES.md.

///|
/// Relation between an expression and zero.
pub(all) enum Relation {
  Equal
  LessEqual
  GreaterEqual
} derive(Eq, @debug.Debug)

///|
pub extend Relation with Eq::{equal, not_equal}

///|
pub extend Relation with @debug.Debug::{to_repr}

///|
/// A constraint handle has identity: keep it to remove the same constraint.
pub struct Constraint {
  priv id : Int
  priv expression : Expression
  relation : Relation
  strength : Double
}

///|
pub fn Constraint::new(
  expression : Expression,
  relation : Relation,
  strength? : Double = 1001001000.0,
) -> Constraint {
  { id: next_identity(), expression, relation, strength, }
}

///|
/// Nonnegative residual, useful for independently checking a solution.
pub fn Constraint::violation(
  self : Constraint,
  solver : Solver,
) -> Double raise SolverError {
  let residual = self.expression.value(solver)
  match self.relation {
    Equal => residual.abs()
    LessEqual => if residual > 0.0 { residual } else { 0.0 }
    GreaterEqual => if residual < 0.0 { -residual } else { 0.0 }
  }
}

///|
pub(all) suberror SolverError {
  DuplicateConstraint
  UnknownConstraint
  UnsatisfiableConstraint
  DuplicateEditVariable
  UnknownEditVariable
  InvalidStrength
  InvalidNumber
  NumericalFailure(String)
  PivotLimit
} derive(Eq, @debug.Debug)

///|
pub extend SolverError with Eq::{equal, not_equal}

///|
pub extend SolverError with @debug.Debug::{to_repr}
