// Kiwi 1.4.9 port: Copyright (c) 2013-2025, Nucleic Development Team.
// MoonBit adaptation: Copyright (c) 2026, MoonCassowary contributors.
// Distributed under BSD-3-Clause; see LICENSE and THIRD_PARTY_NOTICES.md.

///|
/// Required constraints are hard requirements, not terms in the objective.
pub fn required() -> Double {
  1001001000.0
}

///|
/// Soft strengths are scalar weights, not infinite lexicographic priorities.
pub fn strong() -> Double {
  1000000.0
}

///|
pub fn medium() -> Double {
  1000.0
}

///|
pub fn weak() -> Double {
  1.0
}

///|
fn is_finite(value : Double) -> Bool {
  !value.is_nan() && value != @double.infinity && value != @double.neg_infinity
}

///|
fn near_zero(value : Double) -> Bool {
  value.abs() < 1.0e-8
}

///|
fn check_strength(value : Double, edit : Bool) -> Unit raise SolverError {
  if !is_finite(value) ||
    value < 0.0 ||
    value > required() ||
    (edit && value == required()) {
    raise InvalidStrength
  }
}
