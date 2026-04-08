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
pub fn[T : @btree.BTreeElem] OrderTree::set_at(
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
pub fn[T : @btree.BTreeElem] OrderTree::op_set(
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
pub fn[T : @btree.BTreeElem] OrderTree::view(
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
      root.each_slice_in_range(start, end, fn(elem) { result.push(elem) })
      result
    }
  }
}

///|
fn[T : @btree.BTreeElem] delete_range_needs_merge_rebuild(
  root : OrderNode[T],
  start : Int,
  end_ : Int,
) -> Bool {
  // The in-place range planner preserves local structure, but it does not yet
  // perform an unbounded canonicalization pass across the retained ranges.
  // If the kept prefix and suffix are mergeable, rebuild to preserve the
  // historical "fully normalized after delete_range" behavior.
  let mut left_kept : T? = None
  let mut right_kept : T? = None
  root.each_slice_in_range(0, start, fn(elem) { left_kept = Some(elem) })
  root.each_slice_in_range(end_, root.total(), fn(elem) {
    if right_kept is None {
      right_kept = Some(elem)
    }
  })
  match (left_kept, right_kept) {
    (Some(left), Some(right)) => @rle.Mergeable::can_merge(left, right)
    _ => false
  }
}

///|
/// Delete all elements in the span range [start, end_).
///
/// Uses the in-place multi-leaf walker splice when the planned subtree edit
/// preserves the local occupancy bound and the retained prefix/suffix do not
/// require merge normalization. Otherwise it falls back to the kept-slice
/// rebuild path so behavior stays canonical for all valid `Mergeable`
/// implementations.
pub fn[T : @btree.BTreeElem] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  match self.root {
    None => ()
    Some(root) => {
      let total = root.total()
      if start < 0 || start >= end_ || start >= total {
        return
      }
      let rebuild = fn() {
        let end = if end_ > total { total } else { end_ }
        let kept : Array[T] = []
        root.each_slice_in_range(0, start, fn(elem) { kept.push(elem) })
        root.each_slice_in_range(end, total, fn(elem) { kept.push(elem) })
        let rebuilt = OrderTree::from_array(kept, min_degree=self.min_degree)
        self.root = rebuilt.root
        self.size = rebuilt.size
      }
      match plan_delete_range(root, start, end_, self.min_degree) {
        None => rebuild()
        Some(splice) => {
          let new_child_count = splice.original_child_count -
            (splice.end_idx - splice.start_idx) +
            splice.new_children.length()
          if (splice.prefix.length() > 0 && new_child_count < self.min_degree) ||
            delete_range_needs_merge_rebuild(root, start, end_) {
            rebuild()
          } else {
            let propagated = propagate_node_splice(splice, self.min_degree)
            match propagated.overflow {
              None => self.root = normalize_root_after_delete(propagated.node)
              Some(sibling) => {
                let left_total = propagated.node.total()
                let right_total = sibling.total()
                self.root = Some(
                  Internal(
                    children=[propagated.node, sibling],
                    counts=[left_total, right_total],
                    total=left_total + right_total,
                  ),
                )
              }
            }
            self.size = self.size + propagated.leaf_delta
          }
        }
      }
    }
  }
}
