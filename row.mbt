// Port of kiwi/row.h and kiwi/symbol.h (Kiwi 1.4.9).
// Copyright (c) 2013-2025, Nucleic Development Team.
// Copyright (c) 2026, MoonCassowary contributors. BSD-3-Clause; see LICENSE.

///|
priv enum SymbolKind {
  Invalid
  External
  Slack
  ErrorSymbol
  Dummy
} derive(Eq, Hash)

///|
priv struct Symbol {
  id : Int
  kind : SymbolKind
} derive(Eq, Hash)

///|
fn invalid_symbol() -> Symbol {
  { id: 0, kind: Invalid, }
}

///|
fn earlier(candidate : Symbol, current : Symbol) -> Bool {
  current.kind == Invalid || candidate.id < current.id
}

///|
priv struct Row {
  mut constant : Double
  cells : Map[Symbol, Double]
}

///|
fn Row::new(constant : Double) -> Row {
  { constant, cells: Map([]), }
}

///|
fn Row::copy(self : Row) -> Row {
  { constant: self.constant, cells: self.cells.copy(), }
}

///|
fn Row::coefficient(self : Row, symbol : Symbol) -> Double {
  self.cells.get(symbol).unwrap_or(0.0)
}

///|
fn Row::insert(self : Row, symbol : Symbol, coefficient : Double) -> Unit {
  let value = self.coefficient(symbol) + coefficient
  if near_zero(value) {
    self.cells.remove(symbol)
  } else {
    self.cells[symbol] = value
  }
}

///|
fn Row::insert_row(self : Row, other : Row, coefficient : Double) -> Unit {
  self.constant += other.constant * coefficient
  for symbol, value in other.cells {
    self.insert(symbol, value * coefficient)
  }
}

///|
fn Row::scale(self : Row, factor : Double) -> Unit {
  self.constant *= factor
  for (symbol, value) in self.cells.to_array() {
    self.cells[symbol] = value * factor
  }
}

///|
fn Row::solve_for(self : Row, symbol : Symbol) -> Unit raise SolverError {
  let coefficient = self.coefficient(symbol)
  if coefficient == 0.0 || !is_finite(coefficient) {
    raise NumericalFailure("invalid pivot coefficient")
  }
  self.cells.remove(symbol)
  self.scale(-1.0 / coefficient)
  self.check_finite()
}

///|
fn Row::pivot(
  self : Row,
  leaving : Symbol,
  entering : Symbol,
) -> Unit raise SolverError {
  self.insert(leaving, -1.0)
  self.solve_for(entering)
}

///|
fn Row::substitute(self : Row, symbol : Symbol, row : Row) -> Unit {
  if self.cells.get(symbol) is Some(coefficient) {
    self.cells.remove(symbol)
    self.insert_row(row, coefficient)
  }
}

///|
fn Row::check_finite(self : Row) -> Unit raise SolverError {
  if !is_finite(self.constant) {
    raise NumericalFailure("non-finite tableau constant")
  }
  for _, value in self.cells {
    if !is_finite(value) {
      raise NumericalFailure("non-finite tableau coefficient")
    }
  }
}

///|
fn Row::all_dummies(self : Row) -> Bool {
  self.cells.keys().all(symbol => symbol.kind == Dummy)
}

///|
fn Row::pivotable(self : Row) -> Symbol {
  let mut chosen = invalid_symbol()
  for symbol, _ in self.cells {
    if (symbol.kind == Slack || symbol.kind == ErrorSymbol) &&
      earlier(symbol, chosen) {
      chosen = symbol
    }
  }
  chosen
}
