///|
/// Split a full internal node into two halves.
fn[T] split_internal(
  children : Array[OrderNode[T]],
  counts : Array[Int],
) -> (OrderNode[T], OrderNode[T]) {
  let mid = children.length() / 2
  let left_children : Array[OrderNode[T]] = Array::new(capacity=mid)
  let left_counts : Array[Int] = Array::new(capacity=mid)
  let mut left_total = 0
  for i in 0..<mid {
    left_children.push(children[i])
    left_counts.push(counts[i])
    left_total = left_total + counts[i]
  }
  let right_children : Array[OrderNode[T]] = Array::new(
    capacity=children.length() - mid,
  )
  let right_counts : Array[Int] = Array::new(capacity=children.length() - mid)
  let mut right_total = 0
  for i in mid..<children.length() {
    right_children.push(children[i])
    right_counts.push(counts[i])
    right_total = right_total + counts[i]
  }
  (
    Internal(children=left_children, counts=left_counts, total=left_total),
    Internal(children=right_children, counts=right_counts, total=right_total),
  )
}

///|
/// Apply a splice to a parent's children/counts arrays.
fn[T] apply_splice(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  splice : Splice[T],
) -> Unit {
  let remove_count = splice.end_idx - splice.start_idx
  for _ in 0..<remove_count {
    let _ = children.remove_at(splice.start_idx)
    let _ = counts.remove_at(splice.start_idx)
  }
  if splice.new_leaves.length() == 0 {
    return
  }
  for i = splice.new_leaves.length() - 1; i >= 0; i = i - 1 {
    let (elem, span) = splice.new_leaves[i]
    children.insert_at(splice.start_idx, Leaf(elem=elem, span=span))
    counts.insert_at(splice.start_idx, span)
  }
}

///|
fn[T] maybe_split(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?) {
  let total = counts.sum()
  if children.length() > 2 * min_degree {
    let (left, right) = split_internal(children, counts)
    (left, Some(right))
  } else {
    (Internal(children=children, counts=counts, total=total), None)
  }
}

///|
/// Rebuild ancestors after a leaf splice.
fn[T] propagate(
  path : Array[PathFrame[T]],
  splice : Splice[T],
  min_degree : Int,
  leaf_delta : Int,
) -> PropagateResult[T] {
  if path.length() == 0 {
    abort("propagate: empty path")
  }
  let leaf_parent = path[path.length() - 1]
  apply_splice(leaf_parent.children, leaf_parent.counts, splice)
  let (initial_node, initial_overflow) = maybe_split(
    leaf_parent.children,
    leaf_parent.counts,
    min_degree,
  )
  let mut current_node = initial_node
  let mut overflow = initial_overflow
  for i = path.length() - 2; i >= 0; i = i - 1 {
    let frame = path[i]
    frame.children[frame.child_idx] = current_node
    frame.counts[frame.child_idx] = current_node.total()
    match overflow {
      None => ()
      Some(sibling) => {
        frame.children.insert_at(frame.child_idx + 1, sibling)
        frame.counts.insert_at(frame.child_idx + 1, sibling.total())
      }
    }
    let (updated, next_overflow) = maybe_split(
      frame.children,
      frame.counts,
      min_degree,
    )
    current_node = updated
    overflow = next_overflow
  }
  { node: current_node, overflow, leaf_delta }
}
