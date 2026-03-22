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
/// Compute the total span of an array of items.
fn[T : @rle.Spanning] Array::total_span(self : Array[T]) -> Int {
  self.iter().fold(init=0, fn(acc, item) { acc + @rle.Spanning::span(item) })
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
    Leaf(total~, ..) => total
    Internal(total~, ..) => total
  }
}

///|
/// Check if a node is full.
/// Leaves: max items = 2*t - 1.
/// Internal: max children = 2*t.
fn[T] OrderNode::is_full(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(items~, ..) => items.length() >= 2 * min_degree - 1
    Internal(children~, ..) => children.length() >= 2 * min_degree
  }
}

// === General tree-walking helpers ===
// Local methods on ArrayView. Used by navigate, insert, and delete.

///|
/// Walk items by span to find the item at position `pos`.
/// Calls `f(index, offset_within_item)` when found.
fn[T : @rle.Spanning, R] ArrayView::find_by_span(
  self : ArrayView[T],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  loop (self, pos, 0) {
    ([], _, _) => None
    ([item, .. rest], remaining, i) => {
      let s = @rle.Spanning::span(item)
      if remaining < s {
        f(i, remaining)
      } else {
        continue (rest, remaining - s, i + 1)
      }
    }
  }
}

///|
/// Walk cumulative sums to find which slot contains position `pos`.
/// Uses strict `<`: position must be within slot's range.
fn[R] ArrayView::find_by_sum(
  self : ArrayView[Int],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  loop (self, pos, 0) {
    ([], _, _) => None
    ([count, ..], remaining, i) if remaining < count => f(i, remaining)
    ([count, .. rest], remaining, i) =>
      continue (rest, remaining - count, i + 1)
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
  loop (self, pos, 0) {
    ([], _, _) => None
    ([count, ..], remaining, i) if remaining <= count => f(i, remaining)
    ([count, .. rest], remaining, i) =>
      continue (rest, remaining - count, i + 1)
  }
}
