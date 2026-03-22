///|
/// Split a full leaf into two halves.
/// Returns (left, right) where left gets items[0..mid] and right gets items[mid..].
fn[T : @rle.Spanning] split_leaf(
  items : Array[T],
) -> (OrderNode[T], OrderNode[T]) {
  let mid = items.length() / 2
  let left_items : Array[T] = Array::new(capacity=mid)
  for i = 0; i < mid; i = i + 1 {
    left_items.push(items[i])
  }
  let right_items : Array[T] = Array::new(capacity=items.length() - mid)
  for i = mid; i < items.length(); i = i + 1 {
    right_items.push(items[i])
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
  for i = 0; i < mid; i = i + 1 {
    left_children.push(children[i])
    left_counts.push(counts[i])
  }
  let right_children : Array[OrderNode[T]] = Array::new(
    capacity=children.length() - mid,
  )
  let right_counts : Array[Int] = Array::new(capacity=children.length() - mid)
  for i = mid; i < children.length(); i = i + 1 {
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
  // Find insertion index by scanning spans
  let mut remaining = pos
  let mut insert_idx = items.length()
  for i = 0; i < items.length(); i = i + 1 {
    if remaining <= 0 {
      insert_idx = i
      break
    }
    let s = @rle.Spanning::span(items[i])
    if remaining < s {
      insert_idx = i
      break
    }
    remaining = remaining - s
  }
  // Build new items array with the item inserted
  let new_items : Array[T] = Array::new(capacity=items.length() + 1)
  for i = 0; i < insert_idx; i = i + 1 {
    new_items.push(items[i])
  }
  new_items.push(item)
  for i = insert_idx; i < items.length(); i = i + 1 {
    new_items.push(items[i])
  }
  let new_total = total + item_span
  let max_items = 2 * min_degree - 1
  if new_items.length() > max_items {
    let (left, right) = split_leaf(new_items)
    (left, Some(right))
  } else {
    (Leaf(items=new_items, total=new_total), None)
  }
}

///|
/// Insert into an internal node.
fn[T : @rle.Spanning] insert_into_internal(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  _total : Int,
  pos : Int,
  item : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?) {
  // Find which child to descend into
  let mut remaining = pos
  let mut child_idx = children.length() - 1
  for i = 0; i < children.length() - 1; i = i + 1 {
    if remaining <= counts[i] {
      child_idx = i
      break
    }
    remaining = remaining - counts[i]
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
      let new_total = _total + @rle.Spanning::span(item)
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
      let new_total = _total + @rle.Spanning::span(item)
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
/// Position is clamped to [0, span()].
pub fn[T : @rle.Spanning] OrderTree::insert_at(
  self : OrderTree[T],
  pos : Int,
  item : T,
) -> Unit {
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
      let (updated, maybe_sibling) = root.insert(
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
