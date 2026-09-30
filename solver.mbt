// Public MoonBit API around the ported Kiwi 1.4.9 tableau.
// Copyright (c) 2013-2025, Nucleic Development Team.
// Copyright (c) 2026, MoonCassowary contributors. BSD-3-Clause; see LICENSE.

///|
/// An incremental solver. Mutation is transactional: an error restores the
/// previous tableau. Snapshots cost O(tableau size) memory and time per edit;
/// optimization still reuses the existing basis instead of rebuilding it.
pub struct Solver {
  priv mut state : Tableau
}

///|
pub struct Statistics {
  /// Explicit constraints, excluding edit-variable constraints.
  constraints : Int
  edits : Int
  /// Variable symbols are retained until reset, as in Kiwi.
  variables : Int
  rows : Int
  /// Successful optimization/removal pivots since reset.
  pivots : Int
} derive(Eq, @debug.Debug)

///|
pub extend Statistics with Eq::{equal, not_equal}

///|
pub extend Statistics with @debug.Debug::{to_repr}

///|
pub fn Solver::new() -> Solver {
  { state: Tableau::new(), }
}

///|
fn Solver::mutate(
  self : Solver,
  operation : (Tableau) -> Unit raise SolverError,
) -> Unit raise SolverError {
  let backup = self.state.copy()
  errdefer {
    self.state = backup
  }
  self.state.operation_pivots = 0
  operation(self.state)
  self.state.check_finite()
}

///|
fn validate_constraint(constraint : Constraint) -> Unit raise SolverError {
  check_strength(constraint.strength, false)
  if !is_finite(constraint.expression.constant) {
    raise InvalidNumber
  }
  for _, coefficient in constraint.expression.terms {
    if !is_finite(coefficient) {
      raise InvalidNumber
    }
  }
}

///|
pub fn Solver::add_constraint(
  self : Solver,
  constraint : Constraint,
) -> Unit raise SolverError {
  validate_constraint(constraint)
  self.mutate(state => state.add(constraint))
}

///|
pub fn Solver::remove_constraint(
  self : Solver,
  constraint : Constraint,
) -> Unit raise SolverError {
  self.mutate(state => state.remove(constraint))
}

///|
pub fn Solver::has_constraint(self : Solver, constraint : Constraint) -> Bool {
  self.state.constraints.contains(constraint.id)
}

///|
/// Largest absolute residual of every required constraint currently held.
///
/// A caller updating a layout can use this as a correctness assertion: a
/// required relation is either satisfied (near zero) or the solver has a bug
/// or a stale handle. Soft constraints are excluded because they are meant to
/// be traded off.
pub fn Solver::maximum_required_violation(
  self : Solver,
) -> Double raise SolverError {
  let mut worst = 0.0
  for _, entry in self.state.constraints {
    if entry.constraint.strength == required() {
      let violation = entry.constraint.violation(self)
      if violation > worst {
        worst = violation
      }
    }
  }
  worst
}

///|
/// `true` when every required constraint is satisfied within `tolerance`.
/// Tolerance must be finite and nonnegative; otherwise raises `InvalidNumber`.
/// Zero requests an exact residual check. The solver is never mutated.
pub fn Solver::is_satisfied(
  self : Solver,
  tolerance? : Double = 1.0e-8,
) -> Bool raise SolverError {
  if !is_finite(tolerance) || tolerance < 0.0 {
    raise InvalidNumber
  }
  self.maximum_required_violation() <= tolerance
}

///|
/// Register a variable that can be interactively suggested. Required strength
/// is not allowed: a suggestion is a soft preference, not an assignment.
pub fn Solver::add_edit_variable(
  self : Solver,
  variable : Variable,
  strength : Double,
) -> Unit raise SolverError {
  check_strength(strength, true)
  self.mutate(state => state.add_edit(variable, strength))
}

///|
pub fn Solver::remove_edit_variable(
  self : Solver,
  variable : Variable,
) -> Unit raise SolverError {
  self.mutate(state => state.remove_edit(variable))
}

///|
pub fn Solver::has_edit_variable(self : Solver, variable : Variable) -> Bool {
  self.state.edits.contains(variable)
}

///|
/// Reoptimizes the existing basis using dual simplex. May be clamped by hard
/// constraints or outweighed by competing soft preferences.
pub fn Solver::suggest_value(
  self : Solver,
  variable : Variable,
  value : Double,
) -> Unit raise SolverError {
  if !is_finite(value) {
    raise InvalidNumber
  }
  self.mutate(state => state.suggest(variable, value))
}

///|
/// Current solved value. Nonbasic and unknown variables return zero. Reading
/// a variable from another solver never shares or mutates its solved value.
pub fn Solver::value(self : Solver, variable : Variable) -> Double {
  match self.state.variables.get(variable) {
    Some(symbol) =>
      match self.state.rows.get(symbol) {
        Some(row) => row.constant
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Discard constraints, edit registrations, symbols, and pivot counts.
pub fn Solver::reset(self : Solver) -> Unit {
  self.state = Tableau::new()
}

///|
pub fn Solver::statistics(self : Solver) -> Statistics {
  {
    constraints: self.state.constraints.length() - self.state.edits.length(),
    edits: self.state.edits.length(),
    variables: self.state.variables.length(),
    rows: self.state.rows.length(),
    pivots: self.state.pivots,
  }
}
