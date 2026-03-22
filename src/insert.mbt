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
/// Try to merge leaf at `idx` with its right neighbor leaf at `idx+1`.
/// Returns true if merge happened.
fn[T : @rle.Spanning + @rle.Mergeable] try_merge_right(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
) -> Bool {
  if idx + 1 >= children.length() {
    return false
  }
  match (children[idx], children[idx + 1]) {
    (Leaf(elem=left_elem, ..), Leaf(elem=right_elem, ..)) =>
      if @rle.Mergeable::can_merge(left_elem, right_elem) {
        let merged = @rle.Mergeable::merge(left_elem, right_elem)
        let merged_span = @rle.Spanning::span(merged)
        children[idx] = Leaf(elem=merged, span=merged_span)
        counts[idx] = merged_span
        let _ = children.remove_at(idx + 1)
        let _ = counts.remove_at(idx + 1)
        true
      } else {
        false
      }
    _ => false
  }
}

///|
/// Insert an element at a position in an internal node.
/// Returns (updated_node, optional_new_right_sibling, leaf_delta).
/// leaf_delta: net change in leaf count (+1 = new leaf, 0 = merged into existing, etc.).
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderNode::insert(
  self : OrderNode[T],
  pos : Int,
  elem : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?, Int) {
  match self {
    Leaf(..) =>
      abort("OrderNode::insert called on Leaf — should be handled by parent")
    Internal(children~, counts~, total~) =>
      insert_into_internal(children, counts, total, pos, elem, min_degree)
  }
}

///|
/// Insert into an internal node.
/// Returns (updated_node, optional_sibling, leaf_delta).
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] insert_into_internal(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  total : Int,
  pos : Int,
  elem : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?, Int) {
  let elem_span = @rle.Spanning::span(elem)
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
  match children[child_idx] {
    Leaf(elem=existing, span=existing_span) =>
      // Target is a leaf — handle insert at this level
      if remaining == 0 {
        // Insert before this leaf: try merge with left neighbor
        if child_idx > 0 {
          match children[child_idx - 1] {
            Leaf(elem=left_elem, ..) =>
              if @rle.Mergeable::can_merge(left_elem, elem) {
                let merged = @rle.Mergeable::merge(left_elem, elem)
                let merged_span = @rle.Spanning::span(merged)
                children[child_idx - 1] = Leaf(elem=merged, span=merged_span)
                counts[child_idx - 1] = merged_span
                // Try merge the updated left with current — may reduce leaf count
                let mut leaf_delta = 0 // merged into existing, no new leaf
                if try_merge_right(children, counts, child_idx - 1) {
                  leaf_delta = leaf_delta - 1
                }
                let new_total = total + elem_span
                return (
                  Internal(children~, counts~, total=new_total),
                  None,
                  leaf_delta,
                )
              }
            _ => ()
          }
        }
        // Try merge with current leaf
        if @rle.Mergeable::can_merge(elem, existing) {
          let merged = @rle.Mergeable::merge(elem, existing)
          let merged_span = @rle.Spanning::span(merged)
          children[child_idx] = Leaf(elem=merged, span=merged_span)
          counts[child_idx] = merged_span
          let new_total = total + elem_span
          return (Internal(children~, counts~, total=new_total), None, 0)
        }
        // No merge — insert new leaf before current
        let new_leaf = Leaf(elem~, span=elem_span)
        children.insert_at(child_idx, new_leaf)
        counts.insert_at(child_idx, elem_span)
        let new_total = total + elem_span
        if children.length() > 2 * min_degree {
          let (left, right) = split_internal(children, counts)
          (left, Some(right), 1)
        } else {
          (Internal(children~, counts~, total=new_total), None, 1)
        }
      } else if remaining == existing_span {
        // Insert after this leaf: try merge with current
        if @rle.Mergeable::can_merge(existing, elem) {
          let merged = @rle.Mergeable::merge(existing, elem)
          let merged_span = @rle.Spanning::span(merged)
          children[child_idx] = Leaf(elem=merged, span=merged_span)
          counts[child_idx] = merged_span
          // Try merge with right neighbor
          let mut leaf_delta = 0
          if try_merge_right(children, counts, child_idx) {
            leaf_delta = leaf_delta - 1
          }
          let new_total = total + elem_span
          return (
            Internal(children~, counts~, total=new_total),
            None,
            leaf_delta,
          )
        }
        // Try merge with right neighbor
        if child_idx + 1 < children.length() {
          match children[child_idx + 1] {
            Leaf(elem=right_elem, ..) =>
              if @rle.Mergeable::can_merge(elem, right_elem) {
                let merged = @rle.Mergeable::merge(elem, right_elem)
                let merged_span = @rle.Spanning::span(merged)
                children[child_idx + 1] = Leaf(elem=merged, span=merged_span)
                counts[child_idx + 1] = merged_span
                let new_total = total + elem_span
                return (
                  Internal(children~, counts~, total=new_total),
                  None,
                  0, // merged into existing right neighbor
                )
              }
            _ => ()
          }
        }
        // No merge — insert new leaf after current
        let new_leaf = Leaf(elem~, span=elem_span)
        children.insert_at(child_idx + 1, new_leaf)
        counts.insert_at(child_idx + 1, elem_span)
        let new_total = total + elem_span
        if children.length() > 2 * min_degree {
          let (left, right) = split_internal(children, counts)
          (left, Some(right), 1)
        } else {
          (Internal(children~, counts~, total=new_total), None, 1)
        }
      } else {
        // Mid-run insert: split existing element
        let left_part = must_slice(existing, start=0, end=remaining)
        let right_part = must_slice(
          existing,
          start=remaining,
          end=existing_span,
        )
        let left_span = @rle.Spanning::span(left_part)
        let right_span = @rle.Spanning::span(right_part)
        // Try merge left_part with elem
        let mut new_leaves : Array[OrderNode[T]] = []
        let mut new_counts : Array[Int] = []
        let mut current = left_part
        let mut current_span = left_span
        if @rle.Mergeable::can_merge(current, elem) {
          current = @rle.Mergeable::merge(current, elem)
          current_span = @rle.Spanning::span(current)
        } else {
          new_leaves.push(Leaf(elem=current, span=current_span))
          new_counts.push(current_span)
          current = elem
          current_span = elem_span
        }
        // Try merge current with right_part
        if @rle.Mergeable::can_merge(current, right_part) {
          current = @rle.Mergeable::merge(current, right_part)
          current_span = @rle.Spanning::span(current)
          new_leaves.push(Leaf(elem=current, span=current_span))
          new_counts.push(current_span)
        } else {
          new_leaves.push(Leaf(elem=current, span=current_span))
          new_counts.push(current_span)
          new_leaves.push(Leaf(elem=right_part, span=right_span))
          new_counts.push(right_span)
        }
        // leaf_delta = new_leaves.length() - 1 (replacing 1 leaf with N)
        let leaf_delta = new_leaves.length() - 1
        // Replace the original leaf with the new leaves
        let _ = children.remove_at(child_idx)
        let _ = counts.remove_at(child_idx)
        for i = new_leaves.length() - 1; i >= 0; i = i - 1 {
          children.insert_at(child_idx, new_leaves[i])
          counts.insert_at(child_idx, new_counts[i])
        }
        let new_total = total + elem_span
        if children.length() > 2 * min_degree {
          let (left, right) = split_internal(children, counts)
          (left, Some(right), leaf_delta)
        } else {
          (Internal(children~, counts~, total=new_total), None, leaf_delta)
        }
      }
    Internal(..) => {
      // Target is an internal node — proactive split and recurse
      let mut cur_child_idx = child_idx
      let mut cur_remaining = remaining
      if children[cur_child_idx].is_full(min_degree) {
        let child = children[cur_child_idx]
        match child {
          Internal(children=ch, counts=cn, ..) => {
            let (left, right) = split_internal(ch, cn)
            let left_total = left.total()
            children[cur_child_idx] = left
            counts[cur_child_idx] = left_total
            children.insert_at(cur_child_idx + 1, right)
            counts.insert_at(cur_child_idx + 1, right.total())
            if cur_remaining > left_total {
              cur_remaining = cur_remaining - left_total
              cur_child_idx = cur_child_idx + 1
            }
          }
          Leaf(..) => () // Leaves can't be full
        }
      }
      let (updated_child, maybe_sibling, leaf_delta) = children[cur_child_idx].insert(
        cur_remaining, elem, min_degree,
      )
      match maybe_sibling {
        None => {
          children[cur_child_idx] = updated_child
          counts[cur_child_idx] = updated_child.total()
          let new_total = total + elem_span
          (Internal(children~, counts~, total=new_total), None, leaf_delta)
        }
        Some(sibling) => {
          children[cur_child_idx] = updated_child
          counts[cur_child_idx] = updated_child.total()
          children.insert_at(cur_child_idx + 1, sibling)
          counts.insert_at(cur_child_idx + 1, sibling.total())
          let new_total = total + elem_span
          if children.length() > 2 * min_degree {
            let (left, right) = split_internal(children, counts)
            (left, Some(right), leaf_delta)
          } else {
            (Internal(children~, counts~, total=new_total), None, leaf_delta)
          }
        }
      }
    }
  }
}

///|
/// Insert an element at the given position in the tree.
/// Position is clamped to [0, span()]. Element must have span > 0.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::insert_at(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> Unit {
  let elem_span = @rle.Spanning::span(elem)
  guard elem_span > 0 else { return }
  let clamped_pos = if pos < 0 {
    0
  } else if pos > self.span() {
    self.span()
  } else {
    pos
  }
  match self.root {
    None => {
      // Empty tree: create root as internal with single leaf child
      let leaf = Leaf(elem~, span=elem_span)
      self.root = Some(
        Internal(children=[leaf], counts=[elem_span], total=elem_span),
      )
      self.size = 1
    }
    Some(root) => {
      // Pre-split root if full
      let actual_root = if root.is_full(self.min_degree) {
        match root {
          Internal(children~, counts~, ..) => {
            let (left, right) = split_internal(children, counts)
            let left_total = left.total()
            let right_total = right.total()
            Internal(
              children=[left, right],
              counts=[left_total, right_total],
              total=left_total + right_total,
            )
          }
          Leaf(..) => root // Leaves can't be full
        }
      } else {
        root
      }
      let (updated, maybe_sibling, leaf_delta) = actual_root.insert(
        clamped_pos,
        elem,
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
      self.size = self.size + leaf_delta
    }
  }
}
