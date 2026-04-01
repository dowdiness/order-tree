///|
/// Test helper type for invariant tests
priv struct TI {
  value : Int
}

///|
impl @rle.HasLength for TI with length(_self) -> Int {
  1
}

///|
impl @rle.Spanning for TI with span(_self) -> Int {
  1
}

///|
impl @rle.Mergeable for TI with can_merge(_self, _other) -> Bool {
  false
}

///|
impl @rle.Mergeable for TI with merge(_self, _other) -> TI {
  abort("TI::merge: unreachable — can_merge always returns false")
}

///|
impl @rle.Sliceable for TI with slice(self, start~ : Int, end~ : Int) -> Result[
  TI,
  @rle.RleError,
] {
  if start == 0 && end == 1 {
    Ok(self)
  } else {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
}

///|
fn mki(v : Int) -> TI {
  { value: v }
}

///|
/// Returns the leaf depth from this node (all leaves must be at the same depth).
/// Returns None if inconsistent depths are found.
fn[T] leaf_depth(node : OrderNode[T], depth : Int) -> Int? {
  match node {
    Leaf(..) => Some(depth)
    Internal(children~, ..) => {
      let mut expected : Int? = None
      for i = 0; i < children.length(); i = i + 1 {
        match leaf_depth(children[i], depth + 1) {
          None => return None
          Some(d) =>
            match expected {
              None => expected = Some(d)
              Some(e) => if e != d { return None }
            }
        }
      }
      expected
    }
  }
}

///|
/// Check that internal node occupancy is within B-tree bounds.
/// Leaves are exempt from occupancy constraints (they hold exactly one element).
/// Non-root internal: [min_degree, 2*min_degree] children.
fn[T] check_occupancy(
  node : OrderNode[T],
  min_degree : Int,
  is_root : Bool,
) -> String? {
  match node {
    Leaf(..) => None // Leaves have no occupancy constraints
    Internal(children~, ..) => {
      let n = children.length()
      let min_children = min_degree
      let max_children = 2 * min_degree
      if !is_root && n < min_children {
        return Some(
          "internal node has \{n} children, below minimum \{min_children}",
        )
      }
      if n > max_children {
        return Some(
          "internal node has \{n} children, above maximum \{max_children}",
        )
      }
      // Recursively check children (none are roots)
      for i = 0; i < children.length(); i = i + 1 {
        match check_occupancy(children[i], min_degree, false) {
          Some(e) => return Some(e)
          None => ()
        }
      }
      None
    }
  }
}

///|
/// Check that counts arrays match node_total of each child, and totals are sums of counts.
/// Also checks leaf span consistency.
fn[T : @rle.Spanning] check_totals(node : OrderNode[T]) -> String? {
  match node {
    Leaf(elem~, span~) => {
      let actual_span = @rle.Spanning::span(elem)
      if span != actual_span {
        return Some("leaf cached span=\{span} but element span=\{actual_span}")
      }
      if span <= 0 {
        return Some("leaf has zero or negative span=\{span}")
      }
      None
    }
    Internal(children~, counts~, total~) => {
      // Check counts array length matches children array length
      if counts.length() != children.length() {
        return Some(
          "counts.length()=\{counts.length()} != children.length()=\{children.length()}",
        )
      }
      // Check counts[i] == children[i].total()
      for i = 0; i < children.length(); i = i + 1 {
        let ct = children[i].total()
        if counts[i] != ct {
          return Some(
            "counts[\{i}]=\{counts[i]} but children[\{i}].total()=\{ct}",
          )
        }
      }
      // Check total == sum of counts
      let expected_total = counts.sum()
      if total != expected_total {
        return Some(
          "internal total=\{total} but sum of counts=\{expected_total}",
        )
      }
      // Recurse into children
      for i = 0; i < children.length(); i = i + 1 {
        match check_totals(children[i]) {
          Some(e) => return Some(e)
          None => ()
        }
      }
      None
    }
  }
}

///|
/// Count the total number of leaf nodes.
fn[T] count_leaf_items(node : OrderNode[T]) -> Int {
  match node {
    Leaf(..) => 1
    Internal(children~, ..) => {
      let mut total = 0
      for i = 0; i < children.length(); i = i + 1 {
        total = total + count_leaf_items(children[i])
      }
      total
    }
  }
}

///|
/// Check that no two adjacent leaf siblings under the same parent are mergeable.
fn[T : @rle.Mergeable] check_no_adjacent_mergeable(
  node : OrderNode[T],
) -> String? {
  match node {
    Leaf(..) => None
    Internal(children~, ..) => {
      // Check adjacent leaf pairs
      for i = 0; i < children.length() - 1; i = i + 1 {
        match (children[i], children[i + 1]) {
          (Leaf(elem=left, ..), Leaf(elem=right, ..)) =>
            if @rle.Mergeable::can_merge(left, right) {
              return Some(
                "adjacent leaves at indices \{i} and \{i + 1} are mergeable",
              )
            }
          _ => ()
        }
      }
      // Recurse into children
      for i = 0; i < children.length(); i = i + 1 {
        match check_no_adjacent_mergeable(children[i]) {
          Some(e) => return Some(e)
          None => ()
        }
      }
      None
    }
  }
}

///|
/// Check all B-tree invariants for the given tree.
/// Returns None if all invariants hold, Some(error_message) if any is violated.
fn[T : @rle.Spanning + @rle.Mergeable] check_invariants(
  tree : OrderTree[T],
) -> String? {
  match tree.root {
    None => {
      if tree.size != 0 {
        return Some("empty tree but size != 0")
      }
      None
    }
    Some(root) => {
      // 0. Root must be Internal
      match root {
        Leaf(..) => return Some("root is a bare Leaf, should be Internal")
        Internal(..) => ()
      }
      // 1. Leaf depth uniform
      match leaf_depth(root, 0) {
        None => return Some("leaf depth not uniform")
        Some(_) => ()
      }
      // 2. Occupancy (root is exempt from minimum)
      match check_occupancy(root, tree.min_degree, true) {
        Some(e) => return Some(e)
        None => ()
      }
      // 3. Counts/totals correct (including leaf span consistency)
      match check_totals(root) {
        Some(e) => return Some(e)
        None => ()
      }
      // 4. Size matches leaf node count
      let actual_size = count_leaf_items(root)
      if actual_size != tree.size {
        return Some(
          "size mismatch: tree.size=\{tree.size} actual=\{actual_size}",
        )
      }
      // 5. No adjacent mergeable leaves under same parent
      match check_no_adjacent_mergeable(root) {
        Some(e) => return Some(e)
        None => ()
      }
      None
    }
  }
}

///|
test "invariants hold after sequential inserts" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  for i = 0; i < 50; i = i + 1 {
    tree.insert_at(i, mki(i))
    match check_invariants(tree) {
      Some(e) => fail("after insert \{i}: \{e}")
      None => ()
    }
  }
}

///|
test "invariants hold after sequential deletes" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  for i = 0; i < 50; i = i + 1 {
    tree.insert_at(i, mki(i))
  }
  for i = 0; i < 50; i = i + 1 {
    ignore(tree.delete_at(0))
    match check_invariants(tree) {
      Some(e) => fail("after delete \{i}: \{e}")
      None => ()
    }
  }
}

///|
test "invariants hold after from_array" {
  for n = 0; n < 50; n = n + 1 {
    let tree = OrderTree::from_array(
      Array::makei(n, fn(i) { mki(i) }),
      min_degree=2,
    )
    match check_invariants(tree) {
      Some(e) => fail("from_array(\{n}): \{e}")
      None => ()
    }
  }
}

///|
test "invariants hold after mixed insert and delete" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  // Insert 30
  for i = 0; i < 30; i = i + 1 {
    tree.insert_at(i, mki(i))
  }
  // Delete 15 from various positions
  for i = 0; i < 15; i = i + 1 {
    ignore(tree.delete_at(i % tree.span()))
    match check_invariants(tree) {
      Some(e) => fail("after mixed delete \{i}: \{e}")
      None => ()
    }
  }
  // Insert 10 more
  for i = 0; i < 10; i = i + 1 {
    tree.insert_at(i % (tree.span() + 1), mki(100 + i))
    match check_invariants(tree) {
      Some(e) => fail("after mixed insert \{i}: \{e}")
      None => ()
    }
  }
}
