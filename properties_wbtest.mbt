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
