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
  let left_total = compute_items_span(left_items)
  let right_total = compute_items_span(right_items)
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
  let left_total = sum_array(left_counts)
  let right_total = sum_array(right_counts)
  (
    Internal(children=left_children, counts=left_counts, total=left_total),
    Internal(children=right_children, counts=right_counts, total=right_total),
  )
}

///|
/// Compute the total span of an array of items.
fn[T : @rle.Spanning] compute_items_span(items : Array[T]) -> Int {
  let mut total = 0
  for i = 0; i < items.length(); i = i + 1 {
    total = total + @rle.Spanning::span(items[i])
  }
  total
}

///|
/// Sum all elements of an Int array.
fn sum_array(arr : Array[Int]) -> Int {
  let mut total = 0
  for i = 0; i < arr.length(); i = i + 1 {
    total = total + arr[i]
  }
  total
}

///|
/// Get the total span of a node.
fn[T] node_total(node : OrderNode[T]) -> Int {
  match node {
    Leaf(total~, ..) => total
    Internal(total~, ..) => total
  }
}

///|
/// Check if a node is full.
/// Leaves: max items = 2*t - 1.
/// Internal: max children = 2*t.
fn[T] is_node_full(node : OrderNode[T], min_degree : Int) -> Bool {
  let max_items = 2 * min_degree - 1
  match node {
    Leaf(items~, ..) => items.length() >= max_items
    Internal(children~, ..) => children.length() >= 2 * min_degree
  }
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
  if is_node_full(cur_children[cur_child_idx], min_degree) {
    let child = cur_children[cur_child_idx]
    let (left, right) = match child {
      Leaf(items~, ..) => split_leaf(items)
      Internal(children~, counts~, ..) => split_internal(children, counts)
    }
    let left_total = node_total(left)
    // Build new children and counts arrays with the split
    let new_children : Array[OrderNode[T]] = Array::new(
      capacity=cur_children.length() + 1,
    )
    let new_counts : Array[Int] = Array::new(capacity=cur_counts.length() + 1)
    for i = 0; i < cur_child_idx; i = i + 1 {
      new_children.push(cur_children[i])
      new_counts.push(cur_counts[i])
    }
    new_children.push(left)
    new_counts.push(node_total(left))
    new_children.push(right)
    new_counts.push(node_total(right))
    for i = cur_child_idx + 1; i < cur_children.length(); i = i + 1 {
      new_children.push(cur_children[i])
      new_counts.push(cur_counts[i])
    }
    cur_children = new_children
    cur_counts = new_counts
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
      let new_children : Array[OrderNode[T]] = Array::new(
        capacity=cur_children.length(),
      )
      let new_counts : Array[Int] = Array::new(capacity=cur_counts.length())
      for i = 0; i < cur_children.length(); i = i + 1 {
        if i == cur_child_idx {
          new_children.push(updated_child)
          new_counts.push(node_total(updated_child))
        } else {
          new_children.push(cur_children[i])
          new_counts.push(cur_counts[i])
        }
      }
      let new_total = sum_array(new_counts)
      (
        Internal(children=new_children, counts=new_counts, total=new_total),
        None,
      )
    }
    Some(sibling) => {
      // Child split: replace child with updated + insert sibling after it
      let new_children : Array[OrderNode[T]] = Array::new(
        capacity=cur_children.length() + 1,
      )
      let new_counts : Array[Int] = Array::new(capacity=cur_counts.length() + 1)
      for i = 0; i < cur_children.length(); i = i + 1 {
        if i == cur_child_idx {
          new_children.push(updated_child)
          new_counts.push(node_total(updated_child))
          new_children.push(sibling)
          new_counts.push(node_total(sibling))
        } else {
          new_children.push(cur_children[i])
          new_counts.push(cur_counts[i])
        }
      }
      let new_total = sum_array(new_counts)
      let new_node = Internal(
        children=new_children,
        counts=new_counts,
        total=new_total,
      )
      // Check if this internal node is now overfull
      if new_children.length() > 2 * min_degree {
        let (left, right) = split_internal(new_children, new_counts)
        // Need to recompute since split_internal already computes totals
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
          let left_total = node_total(updated)
          let right_total = node_total(sibling)
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
