///|
/// Sum all elements of an Int array.
fn Array::sum(self : Array[Int]) -> Int {
  let mut acc = 0
  for x in self {
    acc += x
  }
  acc
}

///|
/// Unwrap a Sliceable::slice result, aborting on failure.
/// Slice failure at a navigated position indicates a violated precondition.
fn[T : @btree.BTreeElem] must_slice(elem : T, start~ : Int, end~ : Int) -> T {
  match @rle.Sliceable::slice(elem, start~, end~) {
    Ok(result) => result
    Err(_) => abort("OrderTree internal error: slice failed")
  }
}

// === General tree-walking helpers ===
// Local methods on ArrayView. Used by navigate, insert, and delete.

///|
/// Walk cumulative sums to find which slot contains position `pos`.
/// Uses strict `<`: position must be within slot's range.
fn[R] ArrayView::find_by_sum(
  self : ArrayView[Int],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  for view = self, remaining = pos, i = 0 {
    match (view, remaining, i) {
      ([], _, _) => break None
      ([count, ..], remaining, i) if remaining < count => break f(i, remaining)
      ([count, .. rest], remaining, i) =>
        continue rest, remaining - count, i + 1
    }
  }
}

///|
/// Walk cumulative sums to find which slot to insert into at position `pos`.
/// Uses `<=`: position at boundary goes to current slot.
fn[R] ArrayView::find_by_sum_inclusive(
  self : ArrayView[Int],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  for view = self, remaining = pos, i = 0 {
    match (view, remaining, i) {
      ([], _, _) => break None
      ([count, ..], remaining, i) if remaining <= count => break f(i, remaining)
      ([count, .. rest], remaining, i) =>
        continue rest, remaining - count, i + 1
    }
  }
}

///|
fn[T] prepare_noop(
  _children : Array[@btree.BTreeNode[T]],
  _counts : Array[Int],
  _idx : Int,
  _min_degree : Int,
) -> Unit {

}
