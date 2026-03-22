///|
/// Test helper type for invariant tests
priv struct TI {
  value : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for TI with length(_self) -> Int {
  1
}

///|
impl @rle.Spanning for TI with span(_self) -> Int {
  1
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
/// Check that node occupancy is within B-tree bounds.
/// is_root: root is exempt from MINIMUM occupancy only.
/// Maximum occupancy is enforced for all nodes including root
/// (root pre-split in insert_at ensures this).
/// Non-root leaves: [min_degree-1, 2*min_degree-1] items.
/// Non-root internal: [min_degree, 2*min_degree] children.
fn[T] check_occupancy(
  node : OrderNode[T],
  min_degree : Int,
  is_root : Bool,
) -> String? {
  match node {
    Leaf(items~, ..) => {
      let n = items.length()
      let min_items = min_degree - 1
      let max_items = 2 * min_degree - 1
      if not(is_root) && n < min_items {
        return Some("leaf has \{n} items, below minimum \{min_items}")
      }
      if n > max_items {
        return Some("leaf has \{n} items, above maximum \{max_items}")
      }
      None
    }
    Internal(children~, ..) => {
      let n = children.length()
      let min_children = min_degree
      let max_children = 2 * min_degree
      if not(is_root) && n < min_children {
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
fn[T : @rle.Spanning] check_totals(node : OrderNode[T]) -> String? {
  match node {
    Leaf(items~, total~) => {
      let expected = items.total_span()
      if total != expected {
        return Some("leaf total=\{total} but sum of spans=\{expected}")
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
/// Count the total number of leaf items (not spans) across all leaves.
fn[T] count_leaf_items(node : OrderNode[T]) -> Int {
  match node {
    Leaf(items~, ..) => items.length()
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
/// Check all B-tree invariants for the given tree.
/// Returns None if all invariants hold, Some(error_message) if any is violated.
fn[T : @rle.Spanning] check_invariants(tree : OrderTree[T]) -> String? {
  match tree.root {
    None => {
      if tree.size != 0 {
        return Some("empty tree but size != 0")
      }
      None
    }
    Some(root) => {
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
      // 3. Counts/totals correct
      match check_totals(root) {
        Some(e) => return Some(e)
        None => ()
      }
      // 4. Size matches leaf item count
      let actual_size = count_leaf_items(root)
      if actual_size != tree.size {
        return Some(
          "size mismatch: tree.size=\{tree.size} actual=\{actual_size}",
        )
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
