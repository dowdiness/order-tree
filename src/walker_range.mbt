///|
/// Height of a node measured in edges to a leaf.
fn[T] OrderNode::height(self : OrderNode[T]) -> Int {
  match self {
    Leaf(..) => 0
    Internal(children~, ..) =>
      if children.length() == 0 {
        1
      } else {
        children[0].height() + 1
      }
  }
}

///|
/// Count the common path prefix before the first differing child index.
fn[T] shared_prefix_length(
  left : Array[PathFrame[T]],
  right : Array[PathFrame[T]],
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
/// Find the ancestor child interval that spans both leaf cursors.
fn[T] lowest_common_ancestor_range(
  start : LeafCursor[T],
  end_ : LeafCursor[T],
) -> AncestorRange[T] {
  if start.path.length() == 0 || end_.path.length() == 0 {
    abort("lowest_common_ancestor_range: missing leaf parent")
  }
  let prefix_len = shared_prefix_length(start.path, end_.path)
  if prefix_len == start.path.length() && prefix_len == end_.path.length() {
    let target = start.path[prefix_len - 1]
    let prefix = copy_path(start.path, prefix_len - 1)
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
  let prefix = copy_path(start.path, prefix_len)
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
/// Rebuild a single edited leaf back up through a path suffix.
fn[T] build_single_chain(
  path_suffix : Array[PathFrame[T]],
  leaf : OrderNode[T],
) -> OrderNode[T] {
  let mut current = leaf
  for i = path_suffix.length() - 1; i >= 0; i = i - 1 {
    let frame = path_suffix[i]
    let children : Array[OrderNode[T]] = Array::new(
      capacity=frame.children.length(),
    )
    let counts : Array[Int] = Array::new(capacity=frame.counts.length())
    for j = 0; j < frame.children.length(); j = j + 1 {
      if j == frame.child_idx {
        children.push(current)
        counts.push(current.total())
      } else {
        children.push(frame.children[j])
        counts.push(frame.counts[j])
      }
    }
    current = Internal(children=children, counts=counts, total=counts.sum())
  }
  current
}
