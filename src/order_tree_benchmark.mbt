///|
priv struct BItem {
  value : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for BItem with length(_self) {
  1
}

///|
impl @rle.Spanning for BItem with span(_self) {
  1
}

///|
fn bi(v : Int) -> BItem {
  { value: v }
}

///|
fn pseudo_random(n : Int, max : Int) -> Array[Int] {
  let positions : Array[Int] = []
  let mut seed = 12345
  for _i = 0; _i < n; _i = _i + 1 {
    seed = ((seed * 1103515245 + 12345) % 2147483647).abs()
    positions.push(seed % max)
  }
  positions
}

///|
test "bench: insert_at sequential (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new()
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: insert_at sequential (10000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new()
    for i = 0; i < 10000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: insert_at random (1000)" (b : @bench.T) {
  let positions = pseudo_random(1000, 1000)
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new()
    for i = 0; i < 1000; i = i + 1 {
      let pos = positions[i] % (tree.span() + 1)
      tree.insert_at(pos, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: get_at random (1000)" (b : @bench.T) {
  let tree = OrderTree::from_array(Array::makei(1000, fn(i) { bi(i) }))
  let positions = pseudo_random(1000, 1000)
  b.bench(fn() {
    let mut sum = 0
    for i = 0; i < 1000; i = i + 1 {
      match tree.get_at(positions[i] % 1000) {
        Some(v) => sum = sum + v.value
        None => ()
      }
    }
    b.keep(sum)
  })
}

///|
test "bench: delete_at sequential (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree = OrderTree::from_array(Array::makei(1000, fn(i) { bi(i) }))
    for _i = 0; _i < 1000; _i = _i + 1 {
      ignore(tree.delete_at(0))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: from_array (1000)" (b : @bench.T) {
  let items = Array::makei(1000, fn(i) { bi(i) })
  b.bench(fn() {
    let tree = OrderTree::from_array(items)
    b.keep(tree.span())
  })
}

///|
test "bench: from_array (10000)" (b : @bench.T) {
  let items = Array::makei(10000, fn(i) { bi(i) })
  b.bench(fn() {
    let tree = OrderTree::from_array(items)
    b.keep(tree.span())
  })
}

///|
test "bench: iter (1000)" (b : @bench.T) {
  let tree = OrderTree::from_array(Array::makei(1000, fn(i) { bi(i) }))
  b.bench(fn() {
    let mut sum = 0
    tree.each(fn(item) { sum = sum + item.value })
    b.keep(sum)
  })
}

///|
test "bench: min_degree=2 insert (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new(min_degree=2)
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: min_degree=5 insert (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new(min_degree=5)
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: min_degree=10 insert (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new(min_degree=10)
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: min_degree=16 insert (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new(min_degree=16)
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: min_degree=32 insert (1000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BItem] = OrderTree::new(min_degree=32)
    for i = 0; i < 1000; i = i + 1 {
      tree.insert_at(i, bi(i))
    }
    b.keep(tree.span())
  })
}
