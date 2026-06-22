///|
test "property: insert then get roundtrip" {
  // For sizes 0..50, build tree via inserts, verify get_at matches
  for size = 0; size < 50; size = size + 1 {
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    for i = 0; i < size; i = i + 1 {
      tree.insert_at(i, mki(i))
    }
    for i = 0; i < size; i = i + 1 {
      match tree.get_at(i) {
        Some(item) =>
          if item.value != i {
            fail("get_at(\{i}) returned \{item.value}, expected \{i}")
          }
        None => fail("get_at(\{i}) returned None for size \{size}")
      }
    }
  }
}

///|
test "property: delete reduces span" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  for i = 0; i < 30; i = i + 1 {
    tree.insert_at(i, mki(i))
  }
  for i = 0; i < 30; i = i + 1 {
    let before = tree.span()
    ignore(tree.delete_at(0))
    let after = tree.span()
    inspect(before - after == 1, content="true")
  }
}

///|
test "property: from_array then to_array roundtrip" {
  for size = 0; size < 100; size = size + 1 {
    let items = Array::makei(size, fn(i) { mki(i) })
    let tree = OrderTree::from_array(items, min_degree=2)
    let result = tree.to_array()
    if result.length() != size {
      fail("roundtrip size mismatch: \{result.length()} != \{size}")
    }
    for i = 0; i < size; i = i + 1 {
      if result[i].value != i {
        fail("roundtrip value mismatch at \{i}")
      }
    }
  }
}

///|
test "property: random operations maintain invariants" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  let mut seed = 42
  for op = 0; op < 200; op = op + 1 {
    seed = ((seed * 1103515245 + 12345) % 2147483647).abs()
    if tree.span() == 0 || seed % 3 != 0 {
      // Insert at random position
      let pos = if tree.span() == 0 { 0 } else { seed % (tree.span() + 1) }
      tree.insert_at(pos, mki(op))
    } else {
      // Delete at random position
      let pos = seed % tree.span()
      ignore(tree.delete_at(pos))
    }
    match check_invariants(tree) {
      Some(e) => fail("op \{op}: \{e}")
      None => ()
    }
  }
}
