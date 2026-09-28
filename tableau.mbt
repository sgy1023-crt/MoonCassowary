// Port of kiwi/solverimpl.h, Kiwi 1.4.9 (728f5661).
// Copyright (c) 2013-2025, Nucleic Development Team.
// Copyright (c) 2026, MoonCassowary contributors. BSD-3-Clause; see LICENSE.

///|
priv struct Tag {
  marker : Symbol
  other : Symbol
}

///|
priv struct ConstraintEntry {
  constraint : Constraint
  tag : Tag
}

///|
priv struct EditInfo {
  constraint : Constraint
  tag : Tag
  mut constant : Double
}

///|
priv struct Tableau {
  constraints : Map[Int, ConstraintEntry]
  rows : Map[Symbol, Row]
  variables : Map[Variable, Symbol]
  edits : Map[Variable, EditInfo]
  infeasible : Array[Symbol]
  objective : Row
  mut artificial : Row?
  mut next_symbol : Int
  mut pivots : Int
  mut operation_pivots : Int
}

///|
fn Tableau::new() -> Tableau {
  {
    constraints: Map([]),
    rows: Map([]),
    variables: Map([]),
    edits: Map([]),
    infeasible: [],
    objective: Row::new(0.0),
    artificial: None,
    next_symbol: 1,
    pivots: 0,
    operation_pivots: 0,
  }
}

///|
/// Deep copy of mutable numerical state. Constraint expressions are immutable.
fn Tableau::copy(self : Tableau) -> Tableau {
  let rows : Map[Symbol, Row] = Map([])
  for symbol, row in self.rows {
    rows[symbol] = row.copy()
  }
  let edits : Map[Variable, EditInfo] = Map([])
  for variable, info in self.edits {
    edits[variable] = {
      constraint: info.constraint,
      tag: info.tag,
      constant: info.constant,
    }
  }
  {
    constraints: self.constraints.copy(),
    rows,
    variables: self.variables.copy(),
    edits,
    infeasible: self.infeasible.copy(),
    objective: self.objective.copy(),
    artificial: self.artificial.map(row => row.copy()),
    next_symbol: self.next_symbol,
    pivots: self.pivots,
    operation_pivots: 0,
  }
}

///|
fn Tableau::fresh(
  self : Tableau,
  kind : SymbolKind,
) -> Symbol raise SolverError {
  if self.next_symbol == 2147483647 {
    raise NumericalFailure("symbol space exhausted; reset solver")
  }
  let symbol = { id: self.next_symbol, kind, }
  self.next_symbol += 1
  symbol
}

///|
fn Tableau::variable_symbol(
  self : Tableau,
  variable : Variable,
) -> Symbol raise SolverError {
  match self.variables.get(variable) {
    Some(symbol) => symbol
    None => {
      let symbol = self.fresh(External)
      self.variables[variable] = symbol
      symbol
    }
  }
}

///|
fn Tableau::create_row(
  self : Tableau,
  constraint : Constraint,
) -> (Row, Tag) raise SolverError {
  let row = Row::new(constraint.expression.constant)
  for variable, coefficient in constraint.expression.terms {
    if !near_zero(coefficient) {
      let symbol = self.variable_symbol(variable)
      match self.rows.get(symbol) {
        Some(basic) => row.insert_row(basic, coefficient)
        None => row.insert(symbol, coefficient)
      }
    }
  }
  let mut marker = invalid_symbol()
  let mut other = invalid_symbol()
  match constraint.relation {
    LessEqual | GreaterEqual => {
      let coefficient = if constraint.relation == LessEqual {
        1.0
      } else {
        -1.0
      }
      marker = self.fresh(Slack)
      row.insert(marker, coefficient)
      if constraint.strength < required() {
        other = self.fresh(ErrorSymbol)
        row.insert(other, -coefficient)
        self.objective.insert(other, constraint.strength)
      }
    }
    Equal =>
      if constraint.strength < required() {
        marker = self.fresh(ErrorSymbol)
        other = self.fresh(ErrorSymbol)
        row.insert(marker, -1.0)
        row.insert(other, 1.0)
        self.objective.insert(marker, constraint.strength)
        self.objective.insert(other, constraint.strength)
      } else {
        marker = self.fresh(Dummy)
        row.insert(marker, 1.0)
      }
  }
  if row.constant < 0.0 {
    row.scale(-1.0)
  }
  row.check_finite()
  (row, { marker, other, })
}

///|
fn choose_subject(row : Row, tag : Tag) -> Symbol {
  let mut chosen = invalid_symbol()
  for symbol, _ in row.cells {
    if symbol.kind == External && earlier(symbol, chosen) {
      chosen = symbol
    }
  }
  if chosen.kind != Invalid {
    return chosen
  }
  for symbol in [tag.marker, tag.other] {
    if (symbol.kind == Slack || symbol.kind == ErrorSymbol) &&
      row.coefficient(symbol) < 0.0 {
      return symbol
    }
  }
  invalid_symbol()
}

///|
fn Tableau::add(
  self : Tableau,
  constraint : Constraint,
) -> Unit raise SolverError {
  if self.constraints.contains(constraint.id) {
    raise DuplicateConstraint
  }
  let (row, tag) = self.create_row(constraint)
  let mut subject = choose_subject(row, tag)
  if subject.kind == Invalid && row.all_dummies() {
    if !near_zero(row.constant) {
      raise UnsatisfiableConstraint
    }
    subject = tag.marker
  }
  if subject.kind == Invalid {
    if !self.add_artificial(row) {
      raise UnsatisfiableConstraint
    }
  } else {
    row.solve_for(subject)
    self.substitute(subject, row)
    self.rows[subject] = row
  }
  self.constraints[constraint.id] = { constraint, tag, }
  self.optimize(self.objective)
}

///|
fn Tableau::add_artificial(self : Tableau, row : Row) -> Bool raise SolverError {
  let art = self.fresh(Slack)
  self.rows[art] = row.copy()
  let objective = row.copy()
  self.artificial = Some(objective)
  self.optimize(objective)
  let success = near_zero(objective.constant)
  self.artificial = None
  if self.rows.get(art) is Some(basic) {
    self.rows.remove(art)
    if basic.cells.is_empty() {
      return success
    }
    let entering = basic.pivotable()
    if entering.kind == Invalid {
      return false
    }
    self.count_pivot()
    basic.pivot(art, entering)
    self.substitute(entering, basic)
    self.rows[entering] = basic
  }
  for _, basic in self.rows {
    basic.cells.remove(art)
  }
  self.objective.cells.remove(art)
  success
}

///|
fn Tableau::substitute(
  self : Tableau,
  symbol : Symbol,
  row : Row,
) -> Unit raise SolverError {
  for basic, target in self.rows {
    target.substitute(symbol, row)
    target.check_finite()
    if basic.kind != External && target.constant < 0.0 {
      self.infeasible.push(basic)
    }
  }
  self.objective.substitute(symbol, row)
  self.objective.check_finite()
  if self.artificial is Some(objective) {
    objective.substitute(symbol, row)
    objective.check_finite()
  }
}

///|
fn Tableau::count_pivot(self : Tableau) -> Unit raise SolverError {
  if self.operation_pivots >= 10000 {
    raise PivotLimit
  }
  self.operation_pivots += 1
  self.pivots += 1
}

///|
fn entering_symbol(objective : Row) -> Symbol {
  let mut chosen = invalid_symbol()
  for symbol, coefficient in objective.cells {
    if symbol.kind != Dummy && coefficient < 0.0 && earlier(symbol, chosen) {
      chosen = symbol
    }
  }
  chosen
}

///|
fn Tableau::leaving_symbol(self : Tableau, entering : Symbol) -> Symbol {
  let mut chosen = invalid_symbol()
  let mut ratio = @double.infinity
  for symbol, row in self.rows {
    if symbol.kind != External {
      let coefficient = row.coefficient(entering)
      if coefficient < 0.0 {
        let candidate = -row.constant / coefficient
        if candidate < ratio || (candidate == ratio && earlier(symbol, chosen)) {
          chosen = symbol
          ratio = candidate
        }
      }
    }
  }
  chosen
}

///|
fn Tableau::optimize(self : Tableau, objective : Row) -> Unit raise SolverError {
  while true {
    let entering = entering_symbol(objective)
    if entering.kind == Invalid {
      return
    }
    let leaving = self.leaving_symbol(entering)
    if leaving.kind == Invalid {
      raise NumericalFailure("unbounded objective")
    }
    self.count_pivot()
    let row = self.rows[leaving]
    self.rows.remove(leaving)
    row.pivot(leaving, entering)
    self.substitute(entering, row)
    self.rows[entering] = row
  }
}

///|
fn Tableau::dual_entering(self : Tableau, row : Row) -> Symbol {
  let mut chosen = invalid_symbol()
  let mut ratio = @double.infinity
  for symbol, coefficient in row.cells {
    if coefficient > 0.0 && symbol.kind != Dummy {
      let candidate = self.objective.coefficient(symbol) / coefficient
      if candidate < ratio || (candidate == ratio && earlier(symbol, chosen)) {
        ratio = candidate
        chosen = symbol
      }
    }
  }
  chosen
}

///|
fn Tableau::dual_optimize(self : Tableau) -> Unit raise SolverError {
  while self.infeasible.pop() is Some(leaving) {
    if self.rows.get(leaving) is Some(row) &&
      row.constant < 0.0 &&
      !near_zero(row.constant) {
      let entering = self.dual_entering(row)
      if entering.kind == Invalid {
        raise NumericalFailure("dual optimize failed")
      }
      self.count_pivot()
      self.rows.remove(leaving)
      row.pivot(leaving, entering)
      self.substitute(entering, row)
      self.rows[entering] = row
    }
  }
}

///|
fn Tableau::marker_leaving(self : Tableau, marker : Symbol) -> Symbol {
  let mut negative = invalid_symbol()
  let mut positive = invalid_symbol()
  let mut external = invalid_symbol()
  let mut negative_ratio = @double.infinity
  let mut positive_ratio = @double.infinity
  for symbol, row in self.rows {
    let coefficient = row.coefficient(marker)
    if coefficient == 0.0 {
      continue
    }
    if symbol.kind == External {
      if earlier(symbol, external) {
        external = symbol
      }
    } else if coefficient < 0.0 {
      let ratio = -row.constant / coefficient
      if ratio < negative_ratio ||
        (ratio == negative_ratio && earlier(symbol, negative)) {
        negative = symbol
        negative_ratio = ratio
      }
    } else {
      let ratio = row.constant / coefficient
      if ratio < positive_ratio ||
        (ratio == positive_ratio && earlier(symbol, positive)) {
        positive = symbol
        positive_ratio = ratio
      }
    }
  }
  if negative.kind != Invalid {
    negative
  } else if positive.kind != Invalid {
    positive
  } else {
    external
  }
}

///|
fn Tableau::remove_effect(
  self : Tableau,
  marker : Symbol,
  strength : Double,
) -> Unit {
  if marker.kind == ErrorSymbol {
    match self.rows.get(marker) {
      Some(row) => self.objective.insert_row(row, -strength)
      None => self.objective.insert(marker, -strength)
    }
  }
}

///|
fn Tableau::remove(
  self : Tableau,
  constraint : Constraint,
) -> Unit raise SolverError {
  let entry = match self.constraints.get(constraint.id) {
    Some(entry) => entry
    None => raise UnknownConstraint
  }
  self.constraints.remove(constraint.id)
  self.remove_effect(entry.tag.marker, entry.constraint.strength)
  self.remove_effect(entry.tag.other, entry.constraint.strength)
  if self.rows.contains(entry.tag.marker) {
    self.rows.remove(entry.tag.marker)
  } else {
    let leaving = self.marker_leaving(entry.tag.marker)
    if leaving.kind == Invalid {
      raise NumericalFailure("missing constraint marker")
    }
    self.count_pivot()
    let row = self.rows[leaving]
    self.rows.remove(leaving)
    row.pivot(leaving, entry.tag.marker)
    self.substitute(entry.tag.marker, row)
  }
  self.optimize(self.objective)
}

///|
fn Tableau::add_edit(
  self : Tableau,
  variable : Variable,
  strength : Double,
) -> Unit raise SolverError {
  if self.edits.contains(variable) {
    raise DuplicateEditVariable
  }
  let constraint = Constraint::new(
    Expression::new([(variable, 1.0)]),
    Equal,
    strength~,
  )
  self.add(constraint)
  self.edits[variable] = {
    constraint,
    tag: self.constraints[constraint.id].tag,
    constant: 0.0,
  }
}

///|
fn Tableau::remove_edit(
  self : Tableau,
  variable : Variable,
) -> Unit raise SolverError {
  let info = match self.edits.get(variable) {
    Some(info) => info
    None => raise UnknownEditVariable
  }
  self.remove(info.constraint)
  self.edits.remove(variable)
}

///|
fn Tableau::suggest(
  self : Tableau,
  variable : Variable,
  value : Double,
) -> Unit raise SolverError {
  let info = match self.edits.get(variable) {
    Some(info) => info
    None => raise UnknownEditVariable
  }
  let delta = value - info.constant
  if !is_finite(delta) {
    raise NumericalFailure("edit delta overflow")
  }
  info.constant = value
  if self.rows.get(info.tag.marker) is Some(row) {
    row.constant -= delta
    row.check_finite()
    if row.constant < 0.0 {
      self.infeasible.push(info.tag.marker)
    }
  } else if self.rows.get(info.tag.other) is Some(row) {
    row.constant += delta
    row.check_finite()
    if row.constant < 0.0 {
      self.infeasible.push(info.tag.other)
    }
  } else {
    for symbol, row in self.rows {
      let coefficient = row.coefficient(info.tag.marker)
      if coefficient != 0.0 {
        row.constant += delta * coefficient
        row.check_finite()
        if row.constant < 0.0 && symbol.kind != External {
          self.infeasible.push(symbol)
        }
      }
    }
  }
  self.dual_optimize()
}

///|
fn Tableau::check_finite(self : Tableau) -> Unit raise SolverError {
  self.objective.check_finite()
  for _, row in self.rows {
    row.check_finite()
  }
}
