///|
pub fn[T] OrderTree::new(min_degree? : Int) -> OrderTree[T] {
  { tree: @btree.BTree::new(min_degree?) }
}

///|
/// Total leaf entries (number of runs).
pub fn[T] OrderTree::size(self : OrderTree[T]) -> Int {
  self.tree.size()
}

///|
pub impl[T] @rle.HasLength for OrderTree[T] with is_empty(self : OrderTree[T]) -> Bool {
  self.tree.is_empty()
}

///|
/// HasLength: number of leaf entries (same as size).
pub impl[T] @rle.HasLength for OrderTree[T] with length(self) -> Int {
  self.tree.size()
}

///|
/// Spanning: total span across all elements. O(1) via cached root total.
pub impl[T] @rle.Spanning for OrderTree[T] with span(self) -> Int {
  self.tree.span()
}

///|
/// Spanning: logical_length defaults to span for now.
pub impl[T] @rle.Spanning for OrderTree[T] with logical_length(self) -> Int {
  self.tree.span()
}

///|
/// Get the element at span position. Aliased as `tree[pos]`.
#alias("_[_]")
pub fn[T] OrderTree::get_at(self : OrderTree[T], pos : Int) -> T? {
  self.tree.get_at(pos)
}

///|
pub fn[T] OrderTree::find(
  self : OrderTree[T],
  pos : Int,
) -> @btree.FindResult[T]? {
  self.tree.find(pos)
}

///|
/// Replace the element at the given span position.
/// Returns the old single-unit slice, or None if out of bounds.
/// Implemented as delete_at + insert_at to ensure neighbor merging.
pub fn[T : @btree.BTreeElem] OrderTree::set_at(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> T? {
  guard pos >= 0 else { return None }
  let deleted = self.delete_at(pos)
  guard deleted is Some(_) else { return None }
  self.insert_at(pos, elem)
  deleted
}

///|
/// Index setter: `tree[pos] = elem`. Discards the old value.
pub fn[T : @btree.BTreeElem] OrderTree::op_set(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> Unit {
  ignore(self.set_at(pos, elem))
}

///|
/// View operator: `tree[start:end]` returns elements in span range [start, end).
/// Slices at boundaries.
#alias("_[_:_]")
pub fn[T : @btree.BTreeElem] OrderTree::view(
  self : OrderTree[T],
  start? : Int = 0,
  end? : Int,
) -> Array[T] {
  match end {
    Some(e) => self.tree.view(start~, end=e)
    None => self.tree.view(start~)
  }
}

///|
/// Delete all elements in the span range [start, end_).
pub fn[T : @btree.BTreeElem] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  self.tree.delete_range(start, end_)
}
