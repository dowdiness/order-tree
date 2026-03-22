///|
priv struct BItem {
  value : Int
}

///|
impl @rle.HasLength for BItem with length(_self) {
  1
}

///|
impl @rle.Spanning for BItem with span(_self) {
  1
}

///|
impl @rle.Mergeable for BItem with can_merge(_self, _other) -> Bool {
  false
}

///|
impl @rle.Mergeable for BItem with merge(_self, _other) -> BItem {
  abort("BItem::merge: unreachable — can_merge always returns false")
}

///|
impl @rle.Sliceable for BItem with slice(self, start~ : Int, end~ : Int) -> Result[
  BItem,
  @rle.RleError,
] {
  if start == 0 && end == 1 {
    Ok(self)
  } else {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
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

// ====================================================================
// Mergeable benchmark type and benchmarks
// ====================================================================

///|
/// Mergeable benchmark item — merges when consecutive.
priv struct BMItem {
  start : Int
  count : Int
}

///|
impl @rle.HasLength for BMItem with length(self) -> Int {
  self.count
}

///|
impl @rle.Spanning for BMItem with span(self) -> Int {
  self.count
}

///|
impl @rle.Mergeable for BMItem with can_merge(self, other) -> Bool {
  self.start + self.count == other.start
}

///|
impl @rle.Mergeable for BMItem with merge(self, other) -> BMItem {
  { start: self.start, count: self.count + other.count }
}

///|
impl @rle.Sliceable for BMItem with slice(self, start~ : Int, end~ : Int) -> Result[
  BMItem,
  @rle.RleError,
] {
  if start < 0 || end > self.count || start >= end {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  } else {
    Ok({ start: self.start + start, count: end - start })
  }
}

///|
fn bmi(v : Int) -> BMItem {
  { start: v, count: 1 }
}

///|
test "bench: insert_at sequential mergeable (10000)" (b : @bench.T) {
  b.bench(fn() {
    let tree : OrderTree[BMItem] = OrderTree::new()
    for i = 0; i < 10000; i = i + 1 {
      tree.insert_at(i, bmi(i))
    }
    b.keep(tree.span())
  })
}

///|
test "bench: from_array mergeable (10000)" (b : @bench.T) {
  let items : Array[BMItem] = Array::new(capacity=10000)
  for i = 0; i < 10000; i = i + 1 {
    items.push(bmi(i))
  }
  b.bench(fn() {
    let tree = OrderTree::from_array(items, min_degree=10)
    b.keep(tree.span())
  })
}
