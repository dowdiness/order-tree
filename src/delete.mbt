///|
/// Remove an element at the given index from an array, returning the removed element.
/// Shifts subsequent elements left.
fn[T] array_remove(arr : Array[T], idx : Int) -> T {
  let item = arr[idx]
  for i = idx; i < arr.length() - 1; i = i + 1 {
    arr[i] = arr[i + 1]
  }
  let _ = arr.pop()
  item
}

///|
/// Insert an element at the given index in an array.
/// Shifts subsequent elements right.
fn[T] array_insert(arr : Array[T], idx : Int, item : T) -> Unit {
  arr.push(item) // extend length by 1
  for i = arr.length() - 1; i > idx; i = i - 1 {
    arr[i] = arr[i - 1]
  }
  arr[idx] = item
}

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
    (Leaf(items=left_items, ..), Leaf(items=target_items, ..)) => {
      let borrowed = array_remove(left_items, left_items.length() - 1)
      let borrowed_span = @rle.Spanning::span(borrowed)
      array_insert(target_items, 0, borrowed)
      let new_left_total = compute_items_span(left_items)
      let new_target_total = compute_items_span(target_items)
      children[idx - 1] = Leaf(items=left_items, total=new_left_total)
      children[idx] = Leaf(items=target_items, total=new_target_total)
      counts[idx - 1] = new_left_total
      counts[idx] = new_target_total
    }
    (
      Internal(children=left_ch, counts=left_cn, ..),
      Internal(children=target_ch, counts=target_cn, ..),
    ) => {
      let last_idx = left_ch.length() - 1
      let borrowed_child = array_remove(left_ch, last_idx)
      let borrowed_count = array_remove(left_cn, last_idx)
      array_insert(target_ch, 0, borrowed_child)
      array_insert(target_cn, 0, borrowed_count)
      let new_left_total = sum_array(left_cn)
      let new_target_total = sum_array(target_cn)
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
    (Leaf(items=target_items, ..), Leaf(items=right_items, ..)) => {
      let borrowed = array_remove(right_items, 0)
      target_items.push(borrowed)
      let new_target_total = compute_items_span(target_items)
      let new_right_total = compute_items_span(right_items)
      children[idx] = Leaf(items=target_items, total=new_target_total)
      children[idx + 1] = Leaf(items=right_items, total=new_right_total)
      counts[idx] = new_target_total
      counts[idx + 1] = new_right_total
    }
    (
      Internal(children=target_ch, counts=target_cn, ..),
      Internal(children=right_ch, counts=right_cn, ..),
    ) => {
      let borrowed_child = array_remove(right_ch, 0)
      let borrowed_count = array_remove(right_cn, 0)
      target_ch.push(borrowed_child)
      target_cn.push(borrowed_count)
      let new_target_total = sum_array(target_cn)
      let new_right_total = sum_array(right_cn)
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
fn[T : @rle.Spanning] merge_children(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let left = children[idx]
  let right = children[idx + 1]
  let merged = match (left, right) {
    (Leaf(items=left_items, ..), Leaf(items=right_items, ..)) => {
      let new_items : Array[T] = Array::new(
        capacity=left_items.length() + right_items.length(),
      )
      for i = 0; i < left_items.length(); i = i + 1 {
        new_items.push(left_items[i])
      }
      for i = 0; i < right_items.length(); i = i + 1 {
        new_items.push(right_items[i])
      }
      let new_total = compute_items_span(new_items)
      OrderNode::Leaf(items=new_items, total=new_total)
    }
    (
      Internal(children=left_ch, counts=left_cn, ..),
      Internal(children=right_ch, counts=right_cn, ..),
    ) => {
      let new_ch : Array[OrderNode[T]] = Array::new(
        capacity=left_ch.length() + right_ch.length(),
      )
      let new_cn : Array[Int] = Array::new(
        capacity=left_cn.length() + right_cn.length(),
      )
      for i = 0; i < left_ch.length(); i = i + 1 {
        new_ch.push(left_ch[i])
        new_cn.push(left_cn[i])
      }
      for i = 0; i < right_ch.length(); i = i + 1 {
        new_ch.push(right_ch[i])
        new_cn.push(right_cn[i])
      }
      let new_total = sum_array(new_cn)
      OrderNode::Internal(children=new_ch, counts=new_cn, total=new_total)
    }
    _ => abort("merge_children: mismatched node types")
  }
  // Replace left child with merged, remove right child
  children[idx] = merged
  counts[idx] = node_total(merged)
  let _ = array_remove(children, idx + 1)
  let _ = array_remove(counts, idx + 1)
}

///|
/// Returns the number of items (for leaf) or children (for internal) in a node.
fn[T] node_key_count(node : OrderNode[T]) -> Int {
  match node {
    Leaf(items~, ..) => items.length()
    Internal(children~, ..) => children.length()
  }
}

///|
/// Ensure the child at idx has at least min_degree items (for leaf)
/// or min_degree children (for internal).
/// If not, borrow from a sibling or merge.
fn[T : @rle.Spanning] ensure_min_items(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
  min_degree : Int,
) -> Unit {
  let child = children[idx]
  let min_keys = min_degree - 1
  let needs_fix = match child {
    Leaf(items~, ..) => items.length() <= min_keys
    Internal(children=ch, ..) => ch.length() <= min_keys
  }
  if not(needs_fix) {
    return
  }
  // Try borrow from left sibling
  if idx > 0 {
    let left_count = node_key_count(children[idx - 1])
    if left_count > min_keys {
      borrow_from_left(children, counts, idx)
      return
    }
  }
  // Try borrow from right sibling
  if idx < children.length() - 1 {
    let right_count = node_key_count(children[idx + 1])
    if right_count > min_keys {
      borrow_from_right(children, counts, idx)
      return
    }
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
    Leaf(items~, ..) => {
      // Find the item at the given position
      let mut remaining = pos
      let mut delete_idx = -1
      for i = 0; i < items.length(); i = i + 1 {
        let s = @rle.Spanning::span(items[i])
        if remaining < s {
          delete_idx = i
          break
        }
        remaining = remaining - s
      }
      if delete_idx < 0 {
        return (self, None)
      }
      let deleted = array_remove(items, delete_idx)
      let new_total = compute_items_span(items)
      (Leaf(items~, total=new_total), Some(deleted))
    }
    Internal(children~, counts~, ..) => {
      // Find which child contains the target position
      let mut remaining = pos
      let mut child_idx = children.length() - 1
      for i = 0; i < children.length() - 1; i = i + 1 {
        if remaining < counts[i] {
          child_idx = i
          break
        }
        remaining = remaining - counts[i]
      }
      // Ensure the child has enough items before descending
      ensure_min_items(children, counts, child_idx, min_degree)
      // After ensure_min_items, the child_idx may have changed due to merge.
      // If we merged with the left sibling (idx > 0 and merge happened at idx-1),
      // the child is now at idx-1. Recompute which child to descend into.
      let mut new_remaining = pos
      let mut new_child_idx = children.length() - 1
      for i = 0; i < children.length() - 1; i = i + 1 {
        if new_remaining < counts[i] {
          new_child_idx = i
          break
        }
        new_remaining = new_remaining - counts[i]
      }
      let (updated_child, deleted) = children[new_child_idx].delete(
        new_remaining, min_degree,
      )
      children[new_child_idx] = updated_child
      counts[new_child_idx] = node_total(updated_child)
      let new_total = sum_array(counts)
      (Internal(children~, counts~, total=new_total), deleted)
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
      if pos < 0 || pos >= node_total(root) {
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
