///|
/// Borrow the last item from the left sibling and prepend it to child at idx.
/// For leaves: move last item from left to front of target.
/// For internal nodes: move last child from left to front of target.
fn[T : @rle.Spanning] borrow_from_left(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let left = children[idx - 1]
  let target = children[idx]
  match (left, target) {
    (
      Leaf(items=left_items, total=left_total),
      Leaf(items=target_items, total=target_total),
    ) => {
      let borrowed = left_items.remove_at(left_items.length() - 1)
      let borrowed_span = @rle.Spanning::span(borrowed)
      target_items.insert_at(0, borrowed)
      let new_left_total = left_total - borrowed_span
      let new_target_total = target_total + borrowed_span
      children[idx - 1] = Leaf(items=left_items, total=new_left_total)
      children[idx] = Leaf(items=target_items, total=new_target_total)
      counts[idx - 1] = new_left_total
      counts[idx] = new_target_total
    }
    (
      Internal(children=left_ch, counts=left_cn, total=left_total),
      Internal(children=target_ch, counts=target_cn, total=target_total),
    ) => {
      let last_idx = left_ch.length() - 1
      let borrowed_child = left_ch.remove_at(last_idx)
      let borrowed_count = left_cn.remove_at(last_idx)
      target_ch.insert_at(0, borrowed_child)
      target_cn.insert_at(0, borrowed_count)
      let new_left_total = left_total - borrowed_count
      let new_target_total = target_total + borrowed_count
      children[idx - 1] = Internal(
        children=left_ch,
        counts=left_cn,
        total=new_left_total,
      )
      children[idx] = Internal(
        children=target_ch,
        counts=target_cn,
        total=new_target_total,
      )
      counts[idx - 1] = new_left_total
      counts[idx] = new_target_total
    }
    _ => abort("borrow_from_left: mismatched node types")
  }
}

///|
/// Borrow the first item from the right sibling and append it to child at idx.
fn[T : @rle.Spanning] borrow_from_right(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let target = children[idx]
  let right = children[idx + 1]
  match (target, right) {
    (
      Leaf(items=target_items, total=target_total),
      Leaf(items=right_items, total=right_total),
    ) => {
      let borrowed = right_items.remove_at(0)
      let borrowed_span = @rle.Spanning::span(borrowed)
      target_items.push(borrowed)
      let new_target_total = target_total + borrowed_span
      let new_right_total = right_total - borrowed_span
      children[idx] = Leaf(items=target_items, total=new_target_total)
      children[idx + 1] = Leaf(items=right_items, total=new_right_total)
      counts[idx] = new_target_total
      counts[idx + 1] = new_right_total
    }
    (
      Internal(children=target_ch, counts=target_cn, total=target_total),
      Internal(children=right_ch, counts=right_cn, total=right_total),
    ) => {
      let borrowed_child = right_ch.remove_at(0)
      let borrowed_count = right_cn.remove_at(0)
      target_ch.push(borrowed_child)
      target_cn.push(borrowed_count)
      let new_target_total = target_total + borrowed_count
      let new_right_total = right_total - borrowed_count
      children[idx] = Internal(
        children=target_ch,
        counts=target_cn,
        total=new_target_total,
      )
      children[idx + 1] = Internal(
        children=right_ch,
        counts=right_cn,
        total=new_right_total,
      )
      counts[idx] = new_target_total
      counts[idx + 1] = new_right_total
    }
    _ => abort("borrow_from_right: mismatched node types")
  }
}

///|
/// Merge child at idx with child at idx+1 (the right sibling).
/// The right sibling is removed from the parent arrays.
fn[T] merge_children(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let left = children[idx]
  let right = children[idx + 1]
  let merged = match (left, right) {
    (
      Leaf(items=left_items, total=left_total),
      Leaf(items=right_items, total=right_total),
    ) => {
      // Append right items to left (reuse left array)
      for x in right_items {
        left_items.push(x)
      }
      OrderNode::Leaf(items=left_items, total=left_total + right_total)
    }
    (
      Internal(children=left_ch, counts=left_cn, total=left_total),
      Internal(children=right_ch, counts=right_cn, total=right_total),
    ) => {
      // Append right children/counts to left (reuse left arrays)
      for i in 0..<right_ch.length() {
        left_ch.push(right_ch[i])
        left_cn.push(right_cn[i])
      }
      OrderNode::Internal(
        children=left_ch,
        counts=left_cn,
        total=left_total + right_total,
      )
    }
    _ => abort("merge_children: mismatched node types")
  }
  // Replace left child with merged, remove right child
  children[idx] = merged
  counts[idx] = merged.total()
  let _ = children.remove_at(idx + 1)
  let _ = counts.remove_at(idx + 1)
}

///|
/// Whether this node needs rebalancing before a delete descends into it.
/// Leaf: at or below min occupancy (min_degree - 1 items).
/// Internal: at or below min occupancy (min_degree children).
fn[T] OrderNode::needs_rebalance(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(items~, ..) => items.length() <= min_degree - 1
    Internal(children~, ..) => children.length() <= min_degree
  }
}

///|
/// Whether this node has enough entries to lend one to a sibling.
/// Must have strictly MORE than the minimum after lending.
fn[T] OrderNode::can_lend(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(items~, ..) => items.length() > min_degree - 1
    Internal(children~, ..) => children.length() > min_degree
  }
}

///|
/// Ensure the child at idx has enough entries that a delete won't cause underflow.
/// If not, borrow from a sibling or merge.
fn[T : @rle.Spanning] ensure_min_items(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
  min_degree : Int,
) -> Unit {
  if not(children[idx].needs_rebalance(min_degree)) {
    return
  }
  // Try borrow from left sibling
  if idx > 0 && children[idx - 1].can_lend(min_degree) {
    borrow_from_left(children, counts, idx)
    return
  }
  // Try borrow from right sibling
  if idx < children.length() - 1 && children[idx + 1].can_lend(min_degree) {
    borrow_from_right(children, counts, idx)
    return
  }
  // Merge: prefer merging with left sibling if available
  if idx > 0 {
    merge_children(children, counts, idx - 1)
  } else {
    merge_children(children, counts, idx)
  }
}

///|
/// Delete the item at the given span position from this node.
/// Returns the updated node and the deleted item (if found).
fn[T : @rle.Spanning] OrderNode::delete(
  self : OrderNode[T],
  pos : Int,
  min_degree : Int,
) -> (OrderNode[T], T?) {
  match self {
    Leaf(items~, total~) => {
      // Find the item at the given position using shared leaf walker
      let delete_idx = match items[:].find_by_span(pos, (i, _) => Some(i)) {
        Some(i) => i
        None => return (self, None)
      }
      let deleted = items.remove_at(delete_idx)
      let deleted_span = @rle.Spanning::span(deleted)
      (Leaf(items~, total=total - deleted_span), Some(deleted))
    }
    Internal(children~, counts~, total~) => {
      // Find which child contains the target position
      let (child_idx, _) = match
        counts[:counts.length() - 1].find_by_sum(pos, fn(i, r) { Some((i, r)) }) {
        Some(pair) => pair
        None => {
          let last = children.length() - 1
          (last, pos - (total - counts[last]))
        }
      }
      // Ensure the child has enough items before descending.
      // This may merge/borrow, changing array layout.
      ensure_min_items(children, counts, child_idx, min_degree)
      // After ensure_min_items, re-find the child (merge may have shifted indices).
      let (new_child_idx, new_remaining) = match
        counts[:counts.length() - 1].find_by_sum(pos, fn(i, r) { Some((i, r)) }) {
        Some(pair) => pair
        None => {
          let last = children.length() - 1
          (last, pos - (total - counts[last]))
        }
      }
      let (updated_child, deleted) = children[new_child_idx].delete(
        new_remaining, min_degree,
      )
      children[new_child_idx] = updated_child
      let old_count = counts[new_child_idx]
      let new_count = updated_child.total()
      counts[new_child_idx] = new_count
      (
        Internal(children~, counts~, total=total - (old_count - new_count)),
        deleted,
      )
    }
  }
}

///|
/// Delete the item at the given span position from the tree.
/// Returns the deleted item, or None if the position is out of bounds.
pub fn[T : @rle.Spanning] OrderTree::delete_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  match self.root {
    None => None
    Some(root) => {
      if pos < 0 || pos >= root.total() {
        return None
      }
      let (updated, deleted) = root.delete(pos, self.min_degree)
      match deleted {
        None => None
        Some(item) => {
          // Shrink root if needed
          match updated {
            Leaf(items~, ..) =>
              if items.length() == 0 {
                self.root = None
              } else {
                self.root = Some(updated)
              }
            Internal(children~, ..) =>
              if children.length() == 1 {
                self.root = Some(children[0])
              } else if children.length() == 0 {
                self.root = None
              } else {
                self.root = Some(updated)
              }
          }
          self.size = self.size - 1
          Some(item)
        }
      }
    }
  }
}
