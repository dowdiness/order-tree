///|
/// Build an OrderTree from an array of items in O(n) time using bottom-up construction.
/// Items are placed in leaf nodes first, then internal nodes are built layer by layer.
pub fn[T : @rle.Spanning] OrderTree::from_array(
  items : Array[T],
  min_degree? : Int = DEFAULT_MIN_DEGREE,
) -> OrderTree[T] {
  let t = if min_degree < 2 { 2 } else { min_degree }
  if items.is_empty() {
    return OrderTree::new(min_degree=t)
  }
  let max_items = 2 * t - 1
  let n = items.length()

  // --- Build leaf nodes ---
  // Partition items into groups of max_items.
  // If the last group is too small (< t-1 items) and it's not the only group,
  // redistribute from the previous group.
  let groups : Array[Array[T]] = []
  let mut start = 0
  while start < n {
    let end = if start + max_items >= n { n } else { start + max_items }
    let group : Array[T] = Array::new(capacity=end - start)
    for i in start..<end {
      group.push(items[i])
    }
    groups.push(group)
    start = end
  }
  // Fix last group if too small (< t-1 items, i.e. < min_degree - 1)
  // Only do this if there are at least 2 groups.
  let min_items = t - 1
  if groups.length() >= 2 {
    let last_idx = groups.length() - 1
    let last = groups[last_idx]
    if last.length() < min_items {
      // Borrow items from the previous group until both have enough
      let prev = groups[last_idx - 1]
      // Move items from end of prev to beginning of last until both have >= min_items
      // We want to move (prev.length() + last.length()) items across both groups,
      // splitting evenly while keeping both >= min_items
      let total = prev.length() + last.length()
      // prev gets ceil(total/2), last gets floor(total/2)
      let new_prev_count = (total + 1) / 2
      let new_last_count = total - new_prev_count
      // Build new_last from items at the boundary
      let new_last : Array[T] = Array::new(capacity=new_last_count)
      for i in new_prev_count..<(new_prev_count + new_last_count) {
        if i < prev.length() {
          new_last.push(prev[i])
        } else {
          new_last.push(last[i - prev.length()])
        }
      }
      // Trim prev to new_prev_count
      while prev.length() > new_prev_count {
        ignore(prev.pop())
      }
      groups[last_idx] = new_last
    }
  }

  // Create leaf nodes from groups
  let mut current_layer : Array[OrderNode[T]] = Array::new(
    capacity=groups.length(),
  )
  for group in groups {
    let total = group.total_span()
    current_layer.push(Leaf(items=group, total~))
  }

  // --- Build internal layers bottom-up ---
  let max_children = 2 * t
  let min_children = t
  while current_layer.length() > 1 {
    let node_count = current_layer.length()

    // Partition current_layer into groups of max_children
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

    // Fix last group if too small (< min_children) and not the only group
    if child_groups.length() >= 2 {
      let last_idx = child_groups.length() - 1
      let last = child_groups[last_idx]
      if last.length() < min_children {
        let prev = child_groups[last_idx - 1]
        let total = prev.length() + last.length()
        let new_prev_count = (total + 1) / 2
        let new_last_count = total - new_prev_count
        let new_last : Array[OrderNode[T]] = Array::new(capacity=new_last_count)
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

    // Create internal nodes from child groups
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

  // Item count is known from input — no tree walk needed
  let root_node = current_layer[0]
  { root: Some(root_node), min_degree: t, size: n }
}
