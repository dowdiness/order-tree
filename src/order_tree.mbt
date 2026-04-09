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
  match deleted {
    Some(_) => {
      self.insert_at(pos, elem)
      deleted
    }
    None => None
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
fn[T : @btree.BTreeElem] delete_range_needs_merge_rebuild(
  root : @btree.BTreeNode[T],
  start : Int,
  end_ : Int,
) -> Bool {
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
pub fn[T : @btree.BTreeElem] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  match self.tree.root {
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
        let rebuilt = OrderTree::from_array(
          kept,
          min_degree=self.tree.min_degree,
        )
        self.tree.root = rebuilt.tree.root
        self.tree.size = rebuilt.tree.size()
      }
      match plan_delete_range(root, start, end_, self.tree.min_degree) {
        None => rebuild()
        Some(splice) => {
          let new_child_count = splice.original_child_count -
            (splice.end_idx - splice.start_idx) +
            splice.new_children.length()
          if (
              splice.prefix.length() > 0 &&
              new_child_count < self.tree.min_degree
            ) ||
            delete_range_needs_merge_rebuild(root, start, end_) {
            rebuild()
          } else {
            let propagated = @btree.propagate_node_splice(
              splice,
              self.tree.min_degree,
            )
            match propagated.overflow {
              None =>
                self.tree.root = @btree.normalize_root_after_delete(
                  propagated.node,
                )
              Some(sibling) => {
                let left_total = propagated.node.total()
                let right_total = sibling.total()
                self.tree.root = Some(
                  @btree.BTreeNode::Internal(
                    children=[propagated.node, sibling],
                    counts=[left_total, right_total],
                    total=left_total + right_total,
                  ),
                )
              }
            }
            self.tree.size = self.tree.size + propagated.leaf_delta
          }
        }
      }
    }
  }
}
