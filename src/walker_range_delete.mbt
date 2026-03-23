///|
fn[T] path_suffix_after_target(
  path : Array[PathFrame[T]],
  target_depth : Int,
) -> Array[PathFrame[T]] {
  let suffix : Array[PathFrame[T]] = []
  for i = target_depth + 1; i < path.length(); i = i + 1 {
    suffix.push(path[i])
  }
  suffix
}

///|
fn[T] rebuild_boundary_chain(
  path_suffix : Array[PathFrame[T]],
  leaf : OrderNode[T],
  keep_left : Bool,
) -> OrderNode[T] {
  let mut current = leaf
  for i = path_suffix.length() - 1; i >= 0; i = i - 1 {
    let frame = path_suffix[i]
    let children : Array[OrderNode[T]] = []
    let counts : Array[Int] = []
    if keep_left {
      for j = 0; j < frame.child_idx; j = j + 1 {
        children.push(frame.children[j])
        counts.push(frame.counts[j])
      }
      children.push(current)
      counts.push(current.total())
    } else {
      children.push(current)
      counts.push(current.total())
      for j = frame.child_idx + 1; j < frame.children.length(); j = j + 1 {
        children.push(frame.children[j])
        counts.push(frame.counts[j])
      }
    }
    current = Internal(children=children, counts=counts, total=counts.sum())
  }
  current
}

///|
fn[T : @rle.Spanning + @rle.Sliceable] left_boundary_subtree(
  lca : AncestorRange[T],
  start : LeafCursor[T],
) -> OrderNode[T]? {
  if start.offset == 0 {
    return None
  }
  let kept = must_slice(start.elem, start=0, end=start.offset)
  let kept_leaf = Leaf(elem=kept, span=@rle.Spanning::span(kept))
  let target_depth = lca.prefix.length()
  let suffix = path_suffix_after_target(start.path, target_depth)
  Some(rebuild_boundary_chain(suffix, kept_leaf, true))
}

///|
fn[T : @rle.Spanning + @rle.Sliceable] right_boundary_subtree(
  lca : AncestorRange[T],
  end_ : LeafCursor[T],
) -> OrderNode[T]? {
  if end_.offset == end_.span {
    return None
  }
  let kept = must_slice(end_.elem, start=end_.offset, end=end_.span)
  let kept_leaf = Leaf(elem=kept, span=@rle.Spanning::span(kept))
  let target_depth = lca.prefix.length()
  let suffix = path_suffix_after_target(end_.path, target_depth)
  Some(rebuild_boundary_chain(suffix, kept_leaf, false))
}

///|
fn[T] OrderNode::leaf_count(self : OrderNode[T]) -> Int {
  match self {
    Leaf(..) => 1
    Internal(children~, ..) => {
      let mut total = 0
      for child in children {
        total = total + child.leaf_count()
      }
      total
    }
  }
}

///|
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] compute_single_leaf_delete_range(
  leaf : LeafCursor[T],
  start_offset : Int,
  end_offset : Int,
) -> Array[(T, Int)] {
  let new_leaves : Array[(T, Int)] = []
  let left_keep : T? = if start_offset == 0 {
    None
  } else {
    Some(must_slice(leaf.elem, start=0, end=start_offset))
  }
  let right_keep : T? = if end_offset == leaf.span {
    None
  } else {
    Some(must_slice(leaf.elem, start=end_offset, end=leaf.span))
  }
  match (left_keep, right_keep) {
    (None, None) => ()
    (Some(left), None) => new_leaves.push((left, @rle.Spanning::span(left)))
    (None, Some(right)) => new_leaves.push((right, @rle.Spanning::span(right)))
    (Some(left), Some(right)) =>
      if @rle.Mergeable::can_merge(left, right) {
        let merged = @rle.Mergeable::merge(left, right)
        new_leaves.push((merged, @rle.Spanning::span(merged)))
      } else {
        new_leaves.push((left, @rle.Spanning::span(left)))
        new_leaves.push((right, @rle.Spanning::span(right)))
      }
  }
  new_leaves
}

///|
fn[T] leaf_count_of_children(
  children : Array[OrderNode[T]],
  start_idx : Int,
  end_idx : Int,
) -> Int {
  let mut total = 0
  for i = start_idx; i < end_idx; i = i + 1 {
    total = total + children[i].leaf_count()
  }
  total
}

///|
fn[T] leaf_count_of_array(children : Array[OrderNode[T]]) -> Int {
  let mut total = 0
  for child in children {
    total = total + child.leaf_count()
  }
  total
}

///|
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] plan_delete_range(
  root : OrderNode[T],
  start : Int,
  end_ : Int,
  min_degree : Int,
) -> NodeSplice[T]? {
  let total = root.total()
  if start < 0 || start >= end_ || start >= total {
    return None
  }
  let clamped_end = if end_ > total { total } else { end_ }
  let start_cursor = descend_leaf_at(root, start, min_degree)
  let end_cursor = descend_leaf_at_end_boundary(root, clamped_end, min_degree)
  match (start_cursor, end_cursor) {
    (Some(start_leaf), Some(end_leaf)) => {
      let lca = lowest_common_ancestor_range(start_leaf, end_leaf)
      if start_leaf.path.length() == end_leaf.path.length() &&
        shared_prefix_length(start_leaf.path, end_leaf.path) == start_leaf.path.length() {
        let replacement = compute_single_leaf_delete_range(
          start_leaf,
          start_leaf.offset,
          end_leaf.offset,
        )
        let new_children : Array[OrderNode[T]] = []
        for pair in replacement {
          let (elem, span) = pair
          new_children.push(Leaf(elem=elem, span=span))
        }
        let removed_leaf_count = leaf_count_of_children(
          lca.children,
          lca.start_idx,
          lca.end_idx,
        )
        return Some({
          prefix: lca.prefix,
          children: lca.children,
          counts: lca.counts,
          start_idx: lca.start_idx,
          end_idx: lca.end_idx,
          new_children,
          original_child_count: lca.children.length(),
          leaf_delta: leaf_count_of_array(new_children) - removed_leaf_count,
        })
      }
      let new_children : Array[OrderNode[T]] = []
      match left_boundary_subtree(lca, start_leaf) {
        Some(left) => new_children.push(left)
        None => ()
      }
      match right_boundary_subtree(lca, end_leaf) {
        Some(right) => new_children.push(right)
        None => ()
      }
      let removed_leaf_count = leaf_count_of_children(
        lca.children,
        lca.start_idx,
        lca.end_idx,
      )
      Some({
        prefix: lca.prefix,
        children: lca.children,
        counts: lca.counts,
        start_idx: lca.start_idx,
        end_idx: lca.end_idx,
        new_children,
        original_child_count: lca.children.length(),
        leaf_delta: leaf_count_of_array(new_children) - removed_leaf_count,
      })
    }
    _ => None
  }
}
