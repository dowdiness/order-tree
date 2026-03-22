///|
/// Split a full leaf into two halves.
/// Returns (left, right) where left gets items[0..mid] and right gets items[mid..].
fn[T : @rle.Spanning] split_leaf(
  items : Array[T],
) -> (OrderNode[T], OrderNode[T]) {
  let mid = items.length() / 2
  let left_items : Array[T] = Array::new(capacity=mid)
  for item in items[0:mid] {
    left_items.push(item)
  }
  let right_items : Array[T] = Array::new(capacity=items.length() - mid)
  for item in items[mid:] {
    right_items.push(item)
  }
  let left_total = left_items.total_span()
  let right_total = right_items.total_span()
  (
    Leaf(items=left_items, total=left_total),
    Leaf(items=right_items, total=right_total),
  )
}

///|
/// Split a full internal node into two halves.
/// Returns (left, right) where each gets half the children and counts.
fn[T] split_internal(
  children : Array[OrderNode[T]],
  counts : Array[Int],
) -> (OrderNode[T], OrderNode[T]) {
  let mid = children.length() / 2
  let left_children : Array[OrderNode[T]] = Array::new(capacity=mid)
  let left_counts : Array[Int] = Array::new(capacity=mid)
  for i in 0..<mid {
    left_children.push(children[i])
    left_counts.push(counts[i])
  }
  let right_children : Array[OrderNode[T]] = Array::new(
    capacity=children.length() - mid,
  )
  let right_counts : Array[Int] = Array::new(capacity=children.length() - mid)
  for i in mid..<children.length() {
    right_children.push(children[i])
    right_counts.push(counts[i])
  }
  let left_total = left_counts.sum()
  let right_total = right_counts.sum()
  (
    Internal(children=left_children, counts=left_counts, total=left_total),
    Internal(children=right_children, counts=right_counts, total=right_total),
  )
}

///|
/// Insert an item at a position in a node.
/// Returns (updated_node, optional_new_right_sibling).
/// If a split was needed, the new right sibling is returned.
fn[T : @rle.Spanning] OrderNode::insert(
  self : OrderNode[T],
  pos : Int,
  item : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?) {
  match self {
    Leaf(items~, total~) =>
      insert_into_leaf(items, total, pos, item, min_degree)
    Internal(children~, counts~, total~) =>
      insert_into_internal(children, counts, total, pos, item, min_degree)
  }
}

///|
/// Insert into a leaf node.
fn[T : @rle.Spanning] insert_into_leaf(
  items : Array[T],
  total : Int,
  pos : Int,
  item : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?) {
  let item_span = @rle.Spanning::span(item)
  // Find insertion index using shared leaf walker
  let insert_idx = match
    items[:].find_by_span(pos, fn(i, _offset) { Some(i) }) {
    Some(i) => i
    None => items.length()
  }
  items.insert_at(insert_idx, item)
  let new_total = total + item_span
  let max_items = 2 * min_degree - 1
  if items.length() > max_items {
    let (left, right) = split_leaf(items)
    (left, Some(right))
  } else {
    (Leaf(items~, total=new_total), None)
  }
}

///|
/// Insert into an internal node.
fn[T : @rle.Spanning] insert_into_internal(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  total : Int,
  pos : Int,
  item : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?) {
  // Find which child to descend into (inclusive boundary for insert)
  let (child_idx, remaining) = match
    counts[:counts.length() - 1].find_by_sum_inclusive(pos, fn(i, r) {
      Some((i, r))
    }) {
    Some(pair) => pair
    None => {
      // Position is past all children except last — use last child
      let last = children.length() - 1
      (last, pos - (total - counts[last]))
    }
  }
  // Proactive splitting: if the child is full, split it before descending
  let mut cur_children = children
  let mut cur_counts = counts
  let mut cur_child_idx = child_idx
  let mut cur_remaining = remaining
  if cur_children[cur_child_idx].is_full(min_degree) {
    let child = cur_children[cur_child_idx]
    let (left, right) = match child {
      Leaf(items~, ..) => split_leaf(items)
      Internal(children~, counts~, ..) => split_internal(children, counts)
    }
    let left_total = left.total()
    // Use array_insert for proactive split instead of building new arrays
    cur_children[cur_child_idx] = left
    cur_counts[cur_child_idx] = left_total
    cur_children.insert_at(cur_child_idx + 1, right)
    cur_counts.insert_at(cur_child_idx + 1, right.total())
    // Decide which of the two split children to descend into
    if cur_remaining > left_total {
      cur_remaining = cur_remaining - left_total
      cur_child_idx = cur_child_idx + 1
    }
  }
  // Recurse into the selected child
  let (updated_child, maybe_sibling) = cur_children[cur_child_idx].insert(
    cur_remaining, item, min_degree,
  )
  // Build result node
  match maybe_sibling {
    None => {
      // In-place mutation: update the child and count directly
      cur_children[cur_child_idx] = updated_child
      cur_counts[cur_child_idx] = updated_child.total()
      let new_total = total + @rle.Spanning::span(item)
      (
        Internal(children=cur_children, counts=cur_counts, total=new_total),
        None,
      )
    }
    Some(sibling) => {
      // Child split: replace child with updated + insert sibling after it
      cur_children[cur_child_idx] = updated_child
      cur_counts[cur_child_idx] = updated_child.total()
      cur_children.insert_at(cur_child_idx + 1, sibling)
      cur_counts.insert_at(cur_child_idx + 1, sibling.total())
      let new_total = total + @rle.Spanning::span(item)
      let new_node = Internal(
        children=cur_children,
        counts=cur_counts,
        total=new_total,
      )
      // Check if this internal node is now overfull
      if cur_children.length() > 2 * min_degree {
        let (left, right) = split_internal(cur_children, cur_counts)
        (left, Some(right))
      } else {
        (new_node, None)
      }
    }
  }
}

///|
/// Insert an item at the given position in the tree.
/// Position is clamped to [0, span()]. Item must have span > 0.
pub fn[T : @rle.Spanning] OrderTree::insert_at(
  self : OrderTree[T],
  pos : Int,
  item : T,
) -> Unit {
  guard @rle.Spanning::span(item) > 0 else { return }
  let clamped_pos = if pos < 0 {
    0
  } else if pos > self.span() {
    self.span()
  } else {
    pos
  }
  match self.root {
    None => {
      let item_span = @rle.Spanning::span(item)
      self.root = Some(Leaf(items=[item], total=item_span))
    }
    Some(root) => {
      // Pre-split root if full (standard top-down B-tree approach).
      // This ensures the root never exceeds max occupancy after
      // proactive child splits during descent.
      let actual_root = if root.is_full(self.min_degree) {
        let (left, right) = match root {
          Leaf(items~, ..) => split_leaf(items)
          Internal(children~, counts~, ..) => split_internal(children, counts)
        }
        let left_total = left.total()
        let right_total = right.total()
        Internal(
          children=[left, right],
          counts=[left_total, right_total],
          total=left_total + right_total,
        )
      } else {
        root
      }
      let (updated, maybe_sibling) = actual_root.insert(
        clamped_pos,
        item,
        self.min_degree,
      )
      match maybe_sibling {
        None => self.root = Some(updated)
        Some(sibling) => {
          let left_total = updated.total()
          let right_total = sibling.total()
          self.root = Some(
            Internal(
              children=[updated, sibling],
              counts=[left_total, right_total],
              total=left_total + right_total,
            ),
          )
        }
      }
    }
  }
  self.size = self.size + 1
}
