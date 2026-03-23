///|
pub fn[T] OrderTree::new(
  min_degree? : Int = DEFAULT_MIN_DEGREE,
) -> OrderTree[T] {
  let min_degree = if min_degree < 2 { 2 } else { min_degree }
  { root: None, min_degree, size: 0 }
}

///|
/// Total leaf entries (number of runs).
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
/// Spanning: total span across all elements. O(1) via cached root total.
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
/// Get the element at span position. Aliased as `tree[pos]`.
#alias("_[_]")
pub fn[T] OrderTree::get_at(self : OrderTree[T], pos : Int) -> T? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(node) =>
      match node.navigate(pos) {
        Some(result) => Some(result.elem)
        None => None
      }
  }
}

///|
pub fn[T] OrderTree::find(self : OrderTree[T], pos : Int) -> FindResult[T]? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(node) => node.navigate(pos)
  }
}

///|
/// Replace the element at the given span position.
/// Returns the old single-unit slice, or None if out of bounds.
/// Implemented as delete_at + insert_at to ensure neighbor merging.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::set_at(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> T? {
  if pos < 0 {
    return None
  }
  match self.root {
    None => None
    Some(_) => {
      let deleted = self.delete_at(pos)
      match deleted {
        Some(_) => {
          self.insert_at(pos, elem)
          deleted
        }
        None => None // pos was out of bounds
      }
    }
  }
}

///|
/// Index setter: `tree[pos] = elem`. Discards the old value.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::op_set(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> Unit {
  ignore(self.set_at(pos, elem))
}

///|
/// View operator: `tree[start:end]` returns elements in span range [start, end).
/// Slices at boundaries. Uses one descent, then walks leaves in order.
#alias("_[_:_]")
pub fn[T : @rle.Sliceable] OrderTree::view(
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
  match self.root {
    None => result
    Some(root) => {
      let mut pos = start
      let mut cursor = descend(root, start, 0, prepare_noop, find_slot, false)
      while pos < end {
        match cursor {
          None => break
          Some(cur) => {
            let slice_start = cur.offset
            let available = cur.leaf_span - slice_start
            let remaining = end - pos
            let take = if available > remaining { remaining } else { available }
            let slice_end = slice_start + take
            if slice_start == 0 && slice_end == cur.leaf_span {
              result.push(cur.leaf_elem)
            } else {
              result.push(
                must_slice(cur.leaf_elem, start=slice_start, end=slice_end),
              )
            }
            pos = pos + take
            cursor = cursor_next_leaf(cur)
          }
        }
      }
      result
    }
  }
}

///|
/// Delete all elements in the span range [start, end).
/// NOTE: Spec deviation — uses repeated delete_at (O(k * log n)) instead of
/// O(log n + m) bulk algorithm. The bulk algorithm requires a complex multi-leaf
/// removal with boundary slicing that is deferred as a future optimization.
/// Functionally correct, just not optimal for large ranges.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  if start >= end_ {
    return
  }
  // Simple approach: repeated delete_at. Can be optimized later.
  let count = end_ - start
  for _ in 0..<count {
    ignore(self.delete_at(start))
  }
}
