///|
/// Borrow the last child from left sibling and prepend to target.
fn[T] borrow_from_left(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let left = children[idx - 1]
  let target = children[idx]
  match (left, target) {
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
    _ => abort("borrow_from_left: expected internal nodes")
  }
}

///|
/// Borrow the first child from right sibling and append to target.
fn[T] borrow_from_right(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let target = children[idx]
  let right = children[idx + 1]
  match (target, right) {
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
    _ => abort("borrow_from_right: expected internal nodes")
  }
}

///|
/// Merge child at idx with child at idx+1 (both must be Internal).
fn[T] merge_children(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Unit {
  let left = children[idx]
  let right = children[idx + 1]
  match (left, right) {
    (
      Internal(children=left_ch, counts=left_cn, total=left_total),
      Internal(children=right_ch, counts=right_cn, total=right_total),
    ) => {
      for i in 0..<right_ch.length() {
        left_ch.push(right_ch[i])
        left_cn.push(right_cn[i])
      }
      let merged = Internal(
        children=left_ch,
        counts=left_cn,
        total=left_total + right_total,
      )
      children[idx] = merged
      counts[idx] = merged.total()
      let _ = children.remove_at(idx + 1)
      let _ = counts.remove_at(idx + 1)
    }
    _ => abort("merge_children: expected internal nodes")
  }
}

///|
/// Whether this internal node needs rebalancing (too few children).
fn[T] OrderNode::needs_rebalance(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(..) => false // Leaves don't have occupancy constraints
    Internal(children~, ..) => children.length() <= min_degree
  }
}

///|
/// Whether this internal node can lend a child.
fn[T] OrderNode::can_lend(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(..) => false
    Internal(children~, ..) => children.length() > min_degree
  }
}

///|
/// Ensure the child at idx has enough children that a delete won't cause underflow.
fn[T] ensure_min_children(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
  min_degree : Int,
) -> Unit {
  if not(children[idx].needs_rebalance(min_degree)) {
    return
  }
  if idx > 0 && children[idx - 1].can_lend(min_degree) {
    borrow_from_left(children, counts, idx)
    return
  }
  if idx < children.length() - 1 && children[idx + 1].can_lend(min_degree) {
    borrow_from_right(children, counts, idx)
    return
  }
  if idx > 0 {
    merge_children(children, counts, idx - 1)
  } else {
    merge_children(children, counts, idx)
  }
}

///|
/// Delete a single unit at span position from an internal node.
/// Returns (updated_node, deleted_unit, leaf_delta).
/// leaf_delta: net change in leaf count (-1 = leaf removed, 0 = leaf trimmed, +1 = split into two).
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderNode::delete(
  self : OrderNode[T],
  pos : Int,
  min_degree : Int,
) -> (OrderNode[T], T?, Int) {
  match self {
    Leaf(..) =>
      abort("OrderNode::delete called on Leaf — should be handled by parent")
    Internal(children~, counts~, total~) => {
      // Find which child contains the target position
      let (child_idx, remaining) = match
        counts[:counts.length() - 1].find_by_sum(pos, fn(i, r) { Some((i, r)) }) {
        Some(pair) => pair
        None => {
          let last = children.length() - 1
          (last, pos - (total - counts[last]))
        }
      }
      match children[child_idx] {
        Leaf(elem~, span~) =>
          // Delete from this leaf
          if span == 1 {
            // Remove the entire leaf
            let _ = children.remove_at(child_idx)
            let _ = counts.remove_at(child_idx)
            // Try merge new neighbors — may reduce leaf count by 1 more
            let mut leaf_delta = -1
            if child_idx > 0 && child_idx < children.length() {
              if try_merge_right(children, counts, child_idx - 1) {
                leaf_delta = leaf_delta - 1
              }
            }
            (
              Internal(children~, counts~, total=total - 1),
              Some(elem),
              leaf_delta,
            )
          } else if remaining == 0 {
            // Delete first unit
            let deleted = must_slice(elem, start=0, end=1)
            let rest = must_slice(elem, start=1, end=span)
            let rest_span = @rle.Spanning::span(rest)
            children[child_idx] = Leaf(elem=rest, span=rest_span)
            counts[child_idx] = rest_span
            let mut leaf_delta = 0 // leaf trimmed, count unchanged
            if child_idx > 0 {
              if try_merge_right(children, counts, child_idx - 1) {
                leaf_delta = leaf_delta - 1
              }
            }
            (
              Internal(
                children~,
                counts~,
                total=total - @rle.Spanning::span(deleted),
              ),
              Some(deleted),
              leaf_delta,
            )
          } else if remaining == span - 1 {
            // Delete last unit
            let deleted = must_slice(elem, start=span - 1, end=span)
            let rest = must_slice(elem, start=0, end=span - 1)
            let rest_span = @rle.Spanning::span(rest)
            children[child_idx] = Leaf(elem=rest, span=rest_span)
            counts[child_idx] = rest_span
            let mut leaf_delta = 0
            if child_idx + 1 < children.length() {
              if try_merge_right(children, counts, child_idx) {
                leaf_delta = leaf_delta - 1
              }
            }
            (
              Internal(
                children~,
                counts~,
                total=total - @rle.Spanning::span(deleted),
              ),
              Some(deleted),
              leaf_delta,
            )
          } else {
            // Mid-run delete: split into left + right, removing unit at remaining
            let deleted = must_slice(elem, start=remaining, end=remaining + 1)
            let left_part = must_slice(elem, start=0, end=remaining)
            let right_part = must_slice(elem, start=remaining + 1, end=span)
            let left_span = @rle.Spanning::span(left_part)
            let right_span = @rle.Spanning::span(right_part)
            let mut leaf_delta = 0
            if @rle.Mergeable::can_merge(left_part, right_part) {
              let merged = @rle.Mergeable::merge(left_part, right_part)
              let merged_span = @rle.Spanning::span(merged)
              children[child_idx] = Leaf(elem=merged, span=merged_span)
              counts[child_idx] = merged_span
              // leaf_delta = 0 (one leaf stays one leaf)
            } else {
              // Replace with two leaves
              children[child_idx] = Leaf(elem=left_part, span=left_span)
              counts[child_idx] = left_span
              children.insert_at(
                child_idx + 1,
                Leaf(elem=right_part, span=right_span),
              )
              counts.insert_at(child_idx + 1, right_span)
              leaf_delta = 1 // one leaf became two
            }
            (
              Internal(
                children~,
                counts~,
                total=total - @rle.Spanning::span(deleted),
              ),
              Some(deleted),
              leaf_delta,
            )
          }
        Internal(..) => {
          // Ensure child has enough children before descending
          ensure_min_children(children, counts, child_idx, min_degree)
          // Re-find after potential merge
          let (new_idx, new_remaining) = match
            counts[:counts.length() - 1].find_by_sum(pos, fn(i, r) {
              Some((i, r))
            }) {
            Some(pair) => pair
            None => {
              let last = children.length() - 1
              (last, pos - (total - counts[last]))
            }
          }
          let (updated_child, deleted, leaf_delta) = children[new_idx].delete(
            new_remaining, min_degree,
          )
          children[new_idx] = updated_child
          let old_count = counts[new_idx]
          let new_count = updated_child.total()
          counts[new_idx] = new_count
          (
            Internal(children~, counts~, total=total - (old_count - new_count)),
            deleted,
            leaf_delta,
          )
        }
      }
    }
  }
}

///|
/// Delete the element at the given span position from the tree.
/// Returns a single-unit slice of the deleted element.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::delete_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  match self.root {
    None => None
    Some(root) => {
      if pos < 0 || pos >= root.total() {
        return None
      }
      let (updated, deleted, leaf_delta) = root.delete(pos, self.min_degree)
      match deleted {
        None => None
        Some(item) => {
          match updated {
            Internal(children~, ..) =>
              if children.length() == 1 {
                match children[0] {
                  Internal(..) => self.root = Some(children[0])
                  Leaf(..) => self.root = Some(updated)
                }
              } else if children.length() == 0 {
                self.root = None
              } else {
                self.root = Some(updated)
              }
            Leaf(..) => abort("root should always be Internal")
          }
          self.size = self.size + leaf_delta
          Some(item)
        }
      }
    }
  }
}
