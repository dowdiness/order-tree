///|
pub fn[T] OrderTree::new(
  min_degree? : Int = DEFAULT_MIN_DEGREE,
) -> OrderTree[T] {
  let min_degree = if min_degree < 2 { 2 } else { min_degree }
  { root: None, min_degree, size: 0 }
}

///|
/// Total leaf entries.
pub fn[T] OrderTree::size(self : OrderTree[T]) -> Int {
  self.size
}

///|
pub impl[T] @rle.HasLength for OrderTree[T] with is_empty(self : OrderTree[T]) -> Bool {
  self.root is None
}

///|
/// HasLength: number of leaf entries (same as size).
pub impl[T] @rle.HasLength for OrderTree[T] with length(self) -> Int {
  self.size
}

///|
/// Spanning: total span across all items. O(1) via cached root total.
pub impl[T] @rle.Spanning for OrderTree[T] with span(self) -> Int {
  match self.root {
    None => 0
    Some(node) => node.total()
  }
}

///|
/// Spanning: logical_length defaults to span for now.
pub impl[T] @rle.Spanning for OrderTree[T] with logical_length(self) -> Int {
  match self.root {
    None => 0
    Some(node) => node.total()
  }
}

///|
/// Get the item at span position. Aliased as `tree[pos]`.
#alias("_[_]")
pub fn[T : @rle.Spanning] OrderTree::get_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(node) =>
      match node.navigate(pos) {
        Some(result) => Some(result.item)
        None => None
      }
  }
}

///|
pub fn[T : @rle.Spanning] OrderTree::find(
  self : OrderTree[T],
  pos : Int,
) -> FindResult[T]? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(node) => node.navigate(pos)
  }
}

///|
/// Replace the item at the given span position.
/// Returns the old item, or None if the position is out of bounds.
pub fn[T : @rle.Spanning] OrderTree::set_at(
  self : OrderTree[T],
  pos : Int,
  item : T,
) -> T? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(node) => node.set_in_node(pos, item)
  }
}

///|
/// Index setter: `tree[pos] = item`. Discards the old value.
pub fn[T : @rle.Spanning] OrderTree::op_set(
  self : OrderTree[T],
  pos : Int,
  item : T,
) -> Unit {
  ignore(self.set_at(pos, item))
}

///|
/// View operator: `tree[start:end]` returns items in span range [start, end).
/// O(k + log n) where k = items collected.
#alias("_[_:_]")
pub fn[T : @rle.Spanning] OrderTree::view(
  self : OrderTree[T],
  start? : Int = 0,
  end? : Int,
) -> Array[T] {
  let total = @rle.Spanning::span(self)
  let start = if start < 0 { 0 } else { start }
  let end = match end {
    Some(e) => if e > total { total } else { e }
    None => total
  }
  let result : Array[T] = []
  if start >= end || start >= total {
    return result
  }
  // Collect items in [start, end) by navigating to each position
  let mut pos = start
  while pos < end {
    match self.get_at(pos) {
      Some(item) => {
        result.push(item)
        pos = pos + @rle.Spanning::span(item)
      }
      None => break
    }
  }
  result
}

///|
/// Delete all items in the span range [start, end).
/// Uses repeated delete_at(start) calls. O(k log n) where k = end - start.
pub fn[T : @rle.Spanning] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  let count = end_ - start
  for i = 0; i < count; i = i + 1 {
    ignore(self.delete_at(start))
  }
}
