///|
using @btree {type BTreeNode}

///|
/// LCA interval for range operations — local copy because @btree's is priv.
priv struct AncestorRange[T] {
  prefix : Array[@btree.PathFrame[T]]
  children : Array[BTreeNode[T]]
  counts : Array[Int]
  start_idx : Int
  end_idx : Int
  child_height : Int
}

///|
fn[T] shared_prefix_length(
  left : Array[@btree.PathFrame[T]],
  right : Array[@btree.PathFrame[T]],
) -> Int {
  let max_shared = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut i = 0
  while i < max_shared && left[i].child_idx == right[i].child_idx {
    i = i + 1
  }
  i
}

///|
fn[T] lowest_common_ancestor_range(
  start : @btree.LeafCursor[T],
  end_ : @btree.LeafCursor[T],
) -> AncestorRange[T] {
  guard start.path.length() > 0 && end_.path.length() > 0 else {
    abort("lowest_common_ancestor_range: missing leaf parent")
  }
  let prefix_len = shared_prefix_length(start.path, end_.path)
  if prefix_len == start.path.length() && prefix_len == end_.path.length() {
    let target = start.path[prefix_len - 1]
    let prefix = @btree.copy_path(start.path, prefix_len - 1)
    let start_idx = target.child_idx
    return {
      prefix,
      children: target.children,
      counts: target.counts,
      start_idx,
      end_idx: start_idx + 1,
      child_height: if target.children.length() == 0 {
        0
      } else {
        target.children[0].height()
      },
    }
  }
  let target = start.path[prefix_len]
  let prefix = @btree.copy_path(start.path, prefix_len)
  let start_idx = start.path[prefix_len].child_idx
  let end_idx = end_.path[prefix_len].child_idx + 1
  {
    prefix,
    children: target.children,
    counts: target.counts,
    start_idx,
    end_idx,
    child_height: if target.children.length() == 0 {
      0
    } else {
      target.children[0].height()
    },
  }
}

///|
fn[T] path_suffix_after_target(
  path : Array[@btree.PathFrame[T]],
  target_depth : Int,
) -> Array[@btree.PathFrame[T]] {
  let suffix : Array[@btree.PathFrame[T]] = []
  for i = target_depth + 1; i < path.length(); i = i + 1 {
    suffix.push(path[i])
  }
  suffix
}

///|
fn[T] rebuild_boundary_chain(
  path_suffix : Array[@btree.PathFrame[T]],
  leaf : BTreeNode[T],
  keep_left : Bool,
) -> BTreeNode[T] {
  let mut current = leaf
  for i = path_suffix.length() - 1; i >= 0; i = i - 1 {
    let frame = path_suffix[i]
    let children : Array[BTreeNode[T]] = []
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
    current = BTreeNode::Internal(children~, counts~, total=counts.sum())
  }
  current
}

///|
fn[T : @btree.BTreeElem] left_boundary_keep(start : @btree.LeafCursor[T]) -> T? {
  if start.offset == 0 {
    return None
  }
  Some(must_slice(start.elem, start=0, end=start.offset))
}

///|
fn[T : @btree.BTreeElem] right_boundary_keep(end_ : @btree.LeafCursor[T]) -> T? {
  if end_.offset == end_.span {
    return None
  }
  Some(must_slice(end_.elem, start=end_.offset, end=end_.span))
}

///|
fn[T] merge_boundary_chain(
  left_path_suffix : Array[@btree.PathFrame[T]],
  right_path_suffix : Array[@btree.PathFrame[T]],
  leaf : BTreeNode[T],
) -> BTreeNode[T] {
  if left_path_suffix.length() != right_path_suffix.length() {
    abort("merge_boundary_chain: mismatched suffix heights")
  }
  let mut current = leaf
  for i = left_path_suffix.length() - 1; i >= 0; i = i - 1 {
    let left_frame = left_path_suffix[i]
    let right_frame = right_path_suffix[i]
    let children : Array[BTreeNode[T]] = []
    let counts : Array[Int] = []
    for j = 0; j < left_frame.child_idx; j = j + 1 {
      children.push(left_frame.children[j])
      counts.push(left_frame.counts[j])
    }
    children.push(current)
    counts.push(current.total())
    for j = right_frame.child_idx + 1
        j < right_frame.children.length()
        j = j + 1 {
      children.push(right_frame.children[j])
      counts.push(right_frame.counts[j])
    }
    current = BTreeNode::Internal(children~, counts~, total=counts.sum())
  }
  current
}

///|
fn[T] descend_rightmost(
  node : BTreeNode[T],
  prefix : Array[@btree.PathFrame[T]],
) -> @btree.Cursor[T] {
  let path = @btree.copy_path(prefix, prefix.length())
  fn step(current : BTreeNode[T]) -> @btree.Cursor[T] {
    match current {
      Leaf(elem~, span~) => {
        let child_idx = if path.length() == 0 {
          0
        } else {
          path[path.length() - 1].child_idx
        }
        { path, leaf_elem: elem, leaf_span: span, offset: span, child_idx }
      }
      Internal(children~, counts~, ..) => {
        let child_idx = children.length() - 1
        path.push({ children, counts, child_idx })
        step(children[child_idx])
      }
    }
  }
  step(node)
}

///|
fn[T] leftmost_leaf_in_subtree(node : BTreeNode[T]) -> @btree.LeafCursor[T] {
  @btree.LeafCursor::from_cursor(@btree.descend_leftmost(node, []))
}

///|
fn[T] rightmost_leaf_in_subtree(node : BTreeNode[T]) -> @btree.LeafCursor[T] {
  @btree.LeafCursor::from_cursor(descend_rightmost(node, []))
}

///|
fn[T : @btree.BTreeElem] left_boundary_subtree(
  lca : AncestorRange[T],
  start : @btree.LeafCursor[T],
) -> BTreeNode[T]? {
  match left_boundary_keep(start) {
    None => None
    Some(kept) => {
      let kept_leaf = BTreeNode::Leaf(elem=kept, span=@rle.Spanning::span(kept))
      let target_depth = lca.prefix.length()
      let suffix = path_suffix_after_target(start.path, target_depth)
      Some(rebuild_boundary_chain(suffix, kept_leaf, true))
    }
  }
}

///|
fn[T : @btree.BTreeElem] right_boundary_subtree(
  lca : AncestorRange[T],
  end_ : @btree.LeafCursor[T],
) -> BTreeNode[T]? {
  match right_boundary_keep(end_) {
    None => None
    Some(kept) => {
      let kept_leaf = BTreeNode::Leaf(elem=kept, span=@rle.Spanning::span(kept))
      let target_depth = lca.prefix.length()
      let suffix = path_suffix_after_target(end_.path, target_depth)
      Some(rebuild_boundary_chain(suffix, kept_leaf, false))
    }
  }
}

///|
fn[T : @btree.BTreeElem] merged_boundary_subtree(
  lca : AncestorRange[T],
  start : @btree.LeafCursor[T],
  end_ : @btree.LeafCursor[T],
) -> BTreeNode[T]? {
  match (left_boundary_keep(start), right_boundary_keep(end_)) {
    (Some(left), Some(right)) => {
      if !@rle.Mergeable::can_merge(left, right) {
        return None
      }
      let merged = @rle.Mergeable::merge(left, right)
      let merged_leaf = BTreeNode::Leaf(
        elem=merged,
        span=@rle.Spanning::span(merged),
      )
      let target_depth = lca.prefix.length()
      let left_suffix = path_suffix_after_target(start.path, target_depth)
      let right_suffix = path_suffix_after_target(end_.path, target_depth)
      Some(merge_boundary_chain(left_suffix, right_suffix, merged_leaf))
    }
    _ => None
  }
}

///|
fn[T] BTreeNode::leaf_count(self : BTreeNode[T]) -> Int {
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
fn[T : @btree.BTreeElem] compute_single_leaf_delete_range(
  leaf : @btree.LeafCursor[T],
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
  children : Array[BTreeNode[T]],
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
fn[T] leaf_count_of_array(children : Array[BTreeNode[T]]) -> Int {
  let mut total = 0
  for child in children {
    total = total + child.leaf_count()
  }
  total
}

///|
fn[T : @btree.BTreeElem] merge_leaf_nodes(
  left : BTreeNode[T],
  right : BTreeNode[T],
) -> BTreeNode[T]? {
  match (left, right) {
    (Leaf(elem=left_elem, ..), Leaf(elem=right_elem, ..)) =>
      if @rle.Mergeable::can_merge(left_elem, right_elem) {
        let merged = @rle.Mergeable::merge(left_elem, right_elem)
        Some(Leaf(elem=merged, span=@rle.Spanning::span(merged)))
      } else {
        None
      }
    _ => None
  }
}

///|
fn[T : @btree.BTreeElem] absorb_leaf_level_gap_merge(
  lca : AncestorRange[T],
  start : @btree.LeafCursor[T],
  end_ : @btree.LeafCursor[T],
  new_children : Array[BTreeNode[T]],
  start_idx : Int,
  end_idx : Int,
) -> (Array[BTreeNode[T]], Int, Int, Bool) {
  if lca.child_height != 0 {
    return (new_children, start_idx, end_idx, false)
  }
  let mut merged_children = new_children
  let mut merged_start_idx = start_idx
  let mut merged_end_idx = end_idx
  let mut absorbed = false
  if start.offset == 0 &&
    end_.offset == end_.span &&
    start_idx > 0 &&
    end_idx < lca.children.length() &&
    merged_children.length() == 0 {
    match merge_leaf_nodes(lca.children[start_idx - 1], lca.children[end_idx]) {
      Some(merged) => {
        merged_children.push(merged)
        merged_start_idx = start_idx - 1
        merged_end_idx = end_idx + 1
        absorbed = true
      }
      None => ()
    }
  }
  if start.offset == 0 && merged_children.length() > 0 && merged_start_idx > 0 {
    match
      merge_leaf_nodes(lca.children[merged_start_idx - 1], merged_children[0]) {
      Some(merged) => {
        merged_children[0] = merged
        merged_start_idx = merged_start_idx - 1
        absorbed = true
      }
      None => ()
    }
  }
  if end_.offset == end_.span &&
    merged_children.length() > 0 &&
    merged_end_idx < lca.children.length() {
    let last_idx = merged_children.length() - 1
    match
      merge_leaf_nodes(merged_children[last_idx], lca.children[merged_end_idx]) {
      Some(merged) => {
        merged_children[last_idx] = merged
        merged_end_idx = merged_end_idx + 1
        absorbed = true
      }
      None => ()
    }
  }
  (merged_children, merged_start_idx, merged_end_idx, absorbed)
}

///|
fn[T : @btree.BTreeElem] absorb_subtree_gap_merge(
  lca : AncestorRange[T],
  start : @btree.LeafCursor[T],
  end_ : @btree.LeafCursor[T],
  new_children : Array[BTreeNode[T]],
  start_idx : Int,
  end_idx : Int,
) -> (Array[BTreeNode[T]], Int, Int, Bool) {
  if !(start.offset == 0 &&
    end_.offset == end_.span &&
    new_children.length() == 0 &&
    start_idx > 0 &&
    end_idx < lca.children.length()) {
    return (new_children, start_idx, end_idx, false)
  }
  let left_edge = rightmost_leaf_in_subtree(lca.children[start_idx - 1])
  let right_edge = leftmost_leaf_in_subtree(lca.children[end_idx])
  if !@rle.Mergeable::can_merge(left_edge.elem, right_edge.elem) {
    return (new_children, start_idx, end_idx, false)
  }
  let merged = @rle.Mergeable::merge(left_edge.elem, right_edge.elem)
  let merged_leaf = BTreeNode::Leaf(
    elem=merged,
    span=@rle.Spanning::span(merged),
  )
  let merged_subtree = merge_boundary_chain(
    left_edge.path,
    right_edge.path,
    merged_leaf,
  )
  ([merged_subtree], start_idx - 1, end_idx + 1, true)
}

///|
fn[T : @btree.BTreeElem] promote_empty_child_gap_merge(
  lca : AncestorRange[T],
) -> @btree.NodeSplice[T]? {
  if lca.prefix.length() == 0 ||
    lca.start_idx != 0 ||
    lca.end_idx != lca.children.length() {
    return None
  }
  let parent = lca.prefix[lca.prefix.length() - 1]
  let child_idx = parent.child_idx
  if child_idx == 0 || child_idx + 1 >= parent.children.length() {
    return None
  }
  let left_edge = rightmost_leaf_in_subtree(parent.children[child_idx - 1])
  let right_edge = leftmost_leaf_in_subtree(parent.children[child_idx + 1])
  if !@rle.Mergeable::can_merge(left_edge.elem, right_edge.elem) {
    return None
  }
  let merged = @rle.Mergeable::merge(left_edge.elem, right_edge.elem)
  let merged_leaf = BTreeNode::Leaf(
    elem=merged,
    span=@rle.Spanning::span(merged),
  )
  let merged_subtree = merge_boundary_chain(
    left_edge.path,
    right_edge.path,
    merged_leaf,
  )
  let new_children : Array[BTreeNode[T]] = [merged_subtree]
  let removed_leaf_count = leaf_count_of_children(
    parent.children,
    child_idx - 1,
    child_idx + 2,
  )
  Some({
    prefix: @btree.copy_path(lca.prefix, lca.prefix.length() - 1),
    children: parent.children,
    counts: parent.counts,
    start_idx: child_idx - 1,
    end_idx: child_idx + 2,
    new_children,
    original_child_count: parent.children.length(),
    leaf_delta: leaf_count_of_array(new_children) - removed_leaf_count,
  })
}

///|
fn[T : @btree.BTreeElem] plan_delete_range(
  root : BTreeNode[T],
  start : Int,
  end_ : Int,
  min_degree : Int,
) -> @btree.NodeSplice[T]? {
  let total = root.total()
  if start < 0 || start >= end_ || start >= total {
    return None
  }
  let clamped_end = if end_ > total { total } else { end_ }
  let start_cursor = @btree.descend_leaf_at(root, start, min_degree)
  let end_cursor = @btree.descend_leaf_at_end_boundary(
    root, clamped_end, min_degree,
  )
  match (start_cursor, end_cursor) {
    (Some(start_leaf), Some(end_leaf)) => {
      let lca = lowest_common_ancestor_range(start_leaf, end_leaf)
      if start_leaf.path.length() == end_leaf.path.length() &&
        shared_prefix_length(start_leaf.path, end_leaf.path) ==
        start_leaf.path.length() {
        let replacement = compute_single_leaf_delete_range(
          start_leaf,
          start_leaf.offset,
          end_leaf.offset,
        )
        let new_children : Array[BTreeNode[T]] = []
        for pair in replacement {
          let (elem, span) = pair
          new_children.push(BTreeNode::Leaf(elem~, span~))
        }
        let (normalized_children, normalized_start_idx, normalized_end_idx, _) = absorb_subtree_gap_merge(
          lca,
          start_leaf,
          end_leaf,
          new_children,
          lca.start_idx,
          lca.end_idx,
        )
        let (normalized_children, normalized_start_idx, normalized_end_idx, _) = absorb_leaf_level_gap_merge(
          lca, start_leaf, end_leaf, normalized_children, normalized_start_idx, normalized_end_idx,
        )
        let removed_leaf_count = leaf_count_of_children(
          lca.children,
          normalized_start_idx,
          normalized_end_idx,
        )
        if normalized_children.length() == 0 {
          match promote_empty_child_gap_merge(lca) {
            Some(promoted) => return Some(promoted)
            None => ()
          }
        }
        return Some({
          prefix: lca.prefix,
          children: lca.children,
          counts: lca.counts,
          start_idx: normalized_start_idx,
          end_idx: normalized_end_idx,
          new_children: normalized_children,
          original_child_count: lca.children.length(),
          leaf_delta: leaf_count_of_array(normalized_children) -
          removed_leaf_count,
        })
      }
      let new_children : Array[BTreeNode[T]] = []
      match merged_boundary_subtree(lca, start_leaf, end_leaf) {
        Some(merged) => new_children.push(merged)
        None => {
          match left_boundary_subtree(lca, start_leaf) {
            Some(left) => new_children.push(left)
            None => ()
          }
          match right_boundary_subtree(lca, end_leaf) {
            Some(right) => new_children.push(right)
            None => ()
          }
        }
      }
      let (normalized_children, normalized_start_idx, normalized_end_idx, _) = absorb_subtree_gap_merge(
        lca,
        start_leaf,
        end_leaf,
        new_children,
        lca.start_idx,
        lca.end_idx,
      )
      let (normalized_children, normalized_start_idx, normalized_end_idx, _) = absorb_leaf_level_gap_merge(
        lca, start_leaf, end_leaf, normalized_children, normalized_start_idx, normalized_end_idx,
      )
      let removed_leaf_count = leaf_count_of_children(
        lca.children,
        normalized_start_idx,
        normalized_end_idx,
      )
      Some({
        prefix: lca.prefix,
        children: lca.children,
        counts: lca.counts,
        start_idx: normalized_start_idx,
        end_idx: normalized_end_idx,
        new_children: normalized_children,
        original_child_count: lca.children.length(),
        leaf_delta: leaf_count_of_array(normalized_children) -
        removed_leaf_count,
      })
    }
    _ => None
  }
}
