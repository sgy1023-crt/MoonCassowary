// Kiwi 1.4.9 port: Copyright (c) 2013-2025, Nucleic Development Team.
// MoonBit adaptation: Copyright (c) 2026, MoonCassowary contributors.
// Distributed under BSD-3-Clause; see LICENSE and THIRD_PARTY_NOTICES.md.

///|
/// An immutable affine expression, sum(coefficient * variable) + constant.
/// Input arrays are copied and duplicate terms combined. Validation of finite
/// coefficients is performed when the expression enters a solver.
pub struct Expression {
  priv terms : Map[Variable, Double]
  constant : Double
}

///|
pub fn Expression::new(
  terms : Array[(Variable, Double)],
  constant? : Double = 0.0,
) -> Expression {
  let collected : Map[Variable, Double] = Map([])
  for (variable, coefficient) in terms {
    collected[variable] = collected.get(variable).unwrap_or(0.0) + coefficient
  }
  { terms: collected, constant, }
}

///|
/// Reject overflow instead of allowing NaN to masquerade as a valid residual.
pub fn Expression::value(
  self : Expression,
  solver : Solver,
) -> Double raise SolverError {
  let mut value = self.constant
  if !is_finite(value) {
    raise InvalidNumber
  }
  for variable, coefficient in self.terms {
    if !is_finite(coefficient) {
      raise InvalidNumber
    }
    value += coefficient * solver.value(variable)
    if !is_finite(value) {
      raise NumericalFailure("expression evaluation overflow")
    }
  }
  value
}
