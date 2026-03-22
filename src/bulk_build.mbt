///|
/// Build an OrderTree from an array of elements in O(n) time.
/// Filters zero-span items, pre-merges adjacent mergeable elements,
/// then builds bottom-up.
pub fn[T : @rle.Spanning + @rle.Mergeable] OrderTree::from_array(
  items : Array[T],
  min_degree? : Int = DEFAULT_MIN_DEGREE,
) -> OrderTree[T] {
  let t = if min_degree < 2 { 2 } else { min_degree }
  if items.is_empty() {
    return OrderTree::new(min_degree=t)
  }
  // Filter zero-span and pre-merge adjacent elements
  let merged : Array[T] = []
  for item in items {
    if @rle.Spanning::span(item) <= 0 {
      continue
    }
    match merged.last() {
      Some(last) =>
        if @rle.Mergeable::can_merge(last, item) {
          merged[merged.length() - 1] = @rle.Mergeable::merge(last, item)
        } else {
          merged.push(item)
        }
      None => merged.push(item)
    }
  }
  if merged.is_empty() {
    return OrderTree::new(min_degree=t)
  }
  // Create one leaf per merged element
  let mut current_layer : Array[OrderNode[T]] = Array::new(
    capacity=merged.length(),
  )
  for elem in merged {
    let span = @rle.Spanning::span(elem)
    current_layer.push(Leaf(elem~, span~))
  }
  let leaf_count = current_layer.length()
  // Build internal layers bottom-up
  let max_children = 2 * t
  let min_children = t
  while current_layer.length() > 1 {
    let node_count = current_layer.length()
    let child_groups : Array[Array[OrderNode[T]]] = []
    let mut cstart = 0
    while cstart < node_count {
      let cend = if cstart + max_children >= node_count {
        node_count
      } else {
        cstart + max_children
      }
      let cgroup : Array[OrderNode[T]] = Array::new(capacity=cend - cstart)
      for i in cstart..<cend {
        cgroup.push(current_layer[i])
      }
      child_groups.push(cgroup)
      cstart = cend
    }
    // Fix last group if too small
    if child_groups.length() >= 2 {
      let last_idx = child_groups.length() - 1
      let last = child_groups[last_idx]
      if last.length() < min_children {
        let prev = child_groups[last_idx - 1]
        let total = prev.length() + last.length()
        let new_prev_count = (total + 1) / 2
        let new_last_count = total - new_prev_count
        let new_last : Array[OrderNode[T]] = Array::new(
          capacity=new_last_count,
        )
        for i in new_prev_count..<(new_prev_count + new_last_count) {
          if i < prev.length() {
            new_last.push(prev[i])
          } else {
            new_last.push(last[i - prev.length()])
          }
        }
        while prev.length() > new_prev_count {
          ignore(prev.pop())
        }
        child_groups[last_idx] = new_last
      }
    }
    // Create internal nodes
    let next_layer : Array[OrderNode[T]] = Array::new(
      capacity=child_groups.length(),
    )
    for cgroup in child_groups {
      let counts : Array[Int] = Array::new(capacity=cgroup.length())
      for node in cgroup {
        counts.push(node.total())
      }
      let total = counts.sum()
      next_layer.push(Internal(children=cgroup, counts~, total~))
    }
    current_layer = next_layer
  }
  let mut root_node = current_layer[0]
  // Ensure root is always Internal (invariant: root is never a bare Leaf)
  match root_node {
    Leaf(..) => {
      let span = root_node.total()
      root_node = Internal(children=[root_node], counts=[span], total=span)
    }
    Internal(..) => ()
  }
  { root: Some(root_node), min_degree: t, size: leaf_count }
}
