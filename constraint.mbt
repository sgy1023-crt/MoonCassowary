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
/// The relation this constraint enforces.
pub fn Constraint::relation(self : Constraint) -> Relation {
  self.relation
}

///|
/// The weight this constraint carries. `required()` means hard; anything lower
/// participates in the weighted objective and can be traded off.
pub fn Constraint::strength(self : Constraint) -> Double {
  self.strength
}

///|
/// `true` when this constraint cannot be traded off against preferences.
pub fn Constraint::is_required(self : Constraint) -> Bool {
  self.strength == required()
}

///|
/// A readable rendering such as `1*x + -1*y + -10 = 0`, with `<=`/`>=` for
/// inequalities. Useful in diagnostics and in failure messages.
pub fn Constraint::to_repr(self : Constraint) -> String {
  let terms : Array[String] = []
  for variable, coefficient in self.expression.terms {
    terms.push(
      "\{if coefficient < 0.0 { "-" } else { "+" }} \{coefficient.abs()}*\{variable.name}",
    )
  }
  let operator = match self.relation {
    Equal => "="
    LessEqual => "<="
    GreaterEqual => ">="
  }
  let body = if terms.is_empty() {
    "\{self.expression.constant}"
  } else {
    "\{terms.join(" ")} \{if self.expression.constant < 0.0 { "-" } else { "+" }} \{self.expression.constant.abs()}"
  }
  "\{body} \{operator} 0"
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
