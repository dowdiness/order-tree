///|
test "property: insert then get roundtrip" {
  @qc.quick_check_fn(fn(size : Int) -> Bool {
    let r = size % 50
    let size = if r < 0 { -r } else { r }
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    for i = 0; i < size; i = i + 1 {
      tree.insert_at(i, mki(i))
    }
    for i = 0; i < size; i = i + 1 {
      match tree.get_at(i) {
        Some(item) => if item.value != i { return false }
        None => return false
      }
    }
    true
  })
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
    @debug.debug_inspect(before - after == 1, content="true")
  }
}

///|
test "property: from_array then to_array roundtrip" {
  @qc.quick_check_fn(fn(size : Int) -> Bool {
    let r = size % 100
    let size = if r < 0 { -r } else { r }
    let items = Array::makei(size, fn(i) { mki(i) })
    let tree = OrderTree::from_array(items, min_degree=2)
    let result = tree.to_array()
    if result.length() != size {
      return false
    }
    for i = 0; i < size; i = i + 1 {
      if result[i].value != i {
        return false
      }
    }
    true
  })
}

///|
test "property: random operations maintain invariants" {
  @qc.quick_check_fn(fn(ops : Array[Int]) -> Bool {
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    let limit = if ops.length() > 200 { 200 } else { ops.length() }
    for i = 0; i < limit; i = i + 1 {
      let v = ops[i]
      let r = v % 3
      let op_type = if r < 0 { -r } else { r }
      if tree.span() == 0 || op_type != 0 {
        let r = v % (tree.span() + 1)
        let pos = if r < 0 { -r } else { r }
        tree.insert_at(pos, mki(i))
      } else {
        let r = v % tree.span()
        let pos = if r < 0 { -r } else { r }
        ignore(tree.delete_at(pos))
      }
      match check_invariants(tree) {
        Some(_) => return false
        None => ()
      }
    }
    true
  })
}

///|
test "property: invalid set_at preserves non-empty tree state" {
  @qc.quick_check_fn(fn(ops : Array[Int]) -> Bool {
    let limit = if ops.length() > 200 { 200 } else { ops.length() }
    let items = Array::makei(limit + 1, i => {
      if i == 0 {
        mki(0)
      } else {
        mki(ops[i - 1])
      }
    })
    let tree = OrderTree::from_array(items, min_degree=2)
    let seed = if ops.length() == 0 { 0 } else { ops[0] }
    let remainder = seed % tree.span()
    let pos = if remainder < 0 { -remainder } else { remainder }
    let cases = [(0, pos), (-1, (pos + 1) % tree.span())]
    for case in cases {
      let (invalid_span, valid_pos) = case
      let before_content = tree
        .to_array()
        .map(item => (item.value, item.item_span))
      let before_span = tree.span()
      let before_size = tree.size()
      let before_invariants = check_invariants(tree)
      if before_invariants is Some(_) ||
        tree.set_at(valid_pos, { value: invalid_span, item_span: invalid_span })
        is Some(_) ||
        tree.to_array().map(item => (item.value, item.item_span)) !=
        before_content ||
        tree.span() != before_span ||
        tree.size() != before_size ||
        check_invariants(tree) != before_invariants {
        return false
      }
    }
    true
  })
}
