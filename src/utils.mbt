///|
/// Remove an element at the given index, shifting subsequent elements left.
fn[T] Array::remove_at(self : Array[T], idx : Int) -> T {
  let item = self[idx]
  for i in idx..<(self.length() - 1) {
    self[i] = self[i + 1]
  }
  let _ = self.pop()
  item
}

///|
/// Insert an element at the given index, shifting subsequent elements right.
fn[T] Array::insert_at(self : Array[T], idx : Int, item : T) -> Unit {
  self.push(item)
  for i = self.length() - 1; i > idx; i = i - 1 {
    self[i] = self[i - 1]
  }
  self[idx] = item
}

///|
/// Sum all elements of an Int array.
fn Array::sum(self : Array[Int]) -> Int {
  self.iter().fold(init=0, fn(acc, x) { acc + x })
}

///|
/// Get the total span of a node.
fn[T] OrderNode::total(self : OrderNode[T]) -> Int {
  match self {
    Leaf(span~, ..) => span
    Internal(total~, ..) => total
  }
}

///|
/// Check if an internal node is full.
/// Leaves are never "full" in the B-tree sense — they hold exactly one element.
fn[T] OrderNode::is_full(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(..) => false
    Internal(children~, ..) => children.length() >= 2 * min_degree
  }
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
