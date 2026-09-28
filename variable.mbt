// Kiwi 1.4.9 port: Copyright (c) 2013-2025, Nucleic Development Team.
// MoonBit adaptation: Copyright (c) 2026, MoonCassowary contributors.
// Distributed under BSD-3-Clause; see LICENSE and THIRD_PARTY_NOTICES.md.

///|
/// Variables have identity, not name-based equality. The same variable may be
/// used in independent solvers; values are read from the solver, not the handle.
pub struct Variable {
  priv id : Int
  name : String
} derive(Eq, Hash, @debug.Debug)

///|
pub extend Variable with Eq::{equal, not_equal}

///|
pub extend Variable with Hash::{hash, hash_combine}

///|
pub extend Variable with @debug.Debug::{to_repr}

///|
let identity_counter : Ref[Int] = { val: 0, }

///|
fn next_identity() -> Int {
  if identity_counter.val == 2147483647 {
    abort("variable/constraint identity space exhausted")
  }
  identity_counter.val += 1
  identity_counter.val
}

///|
pub fn Variable::new(name : String) -> Variable {
  { id: next_identity(), name, }
}
