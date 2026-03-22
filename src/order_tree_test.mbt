///|
priv struct TItem {
  value : Int
} derive(Show)

///|
impl @rle.HasLength for TItem with length(_self) -> Int {
  1
}

///|
impl @rle.Spanning for TItem with span(_self) -> Int {
  1
}

///|
impl @rle.Mergeable for TItem with can_merge(_self, _other) -> Bool {
  false
}

///|
impl @rle.Mergeable for TItem with merge(_self, _other) -> TItem {
  abort("TItem::merge: unreachable — can_merge always returns false")
}

///|
impl @rle.Sliceable for TItem with slice(self, start~ : Int, end~ : Int) -> Result[
  TItem,
  @rle.RleError,
] {
  if start == 0 && end == 1 {
    Ok(self)
  } else {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
}

///|
fn ti(v : Int) -> TItem {
  { value: v }
}

///|
test "new creates empty tree" {
  let tree : OrderTree[TItem] = OrderTree::new()
  inspect(tree.span(), content="0")
  inspect(tree.size(), content="0")
  inspect(tree.is_empty(), content="true")
}

///|
test "get_at on empty tree returns None" {
  let tree : OrderTree[TItem] = OrderTree::new()
  inspect(tree.get_at(0), content="None")
}

///|
test "find on empty tree returns None" {
  let tree : OrderTree[TItem] = OrderTree::new()
  inspect(tree.find(0), content="None")
}

///|
test "insert_at into empty tree" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(42))
  inspect(tree.span(), content="1")
  inspect(tree.size(), content="1")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(42)")
}

///|
test "insert_at at beginning" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(1))
  tree.insert_at(0, ti(2))
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(2)")
  inspect(tree.get_at(1).map(fn(t) { t.value }), content="Some(1)")
}

///|
test "insert_at at end" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  inspect(tree.span(), content="5")
  for i = 0; i < 5; i = i + 1 {
    inspect(tree.get_at(i).map(fn(t) { t.value }) == Some(i), content="true")
  }
}

///|
test "insert_at in middle" {
  let tree : OrderTree[TItem] = OrderTree::new()
  // Insert 0,1,2,3,4
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  // Insert 99 at position 2
  tree.insert_at(2, ti(99))
  inspect(tree.span(), content="6")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(0)")
  inspect(tree.get_at(1).map(fn(t) { t.value }), content="Some(1)")
  inspect(tree.get_at(2).map(fn(t) { t.value }), content="Some(99)")
  inspect(tree.get_at(3).map(fn(t) { t.value }), content="Some(2)")
}

///|
test "insert_at triggers leaf split" {
  let tree : OrderTree[TItem] = OrderTree::new(min_degree=2)
  // max items per leaf = 2*2-1 = 3. Insert 4 to trigger split.
  for i = 0; i < 4; i = i + 1 {
    tree.insert_at(i, ti(i * 10))
  }
  inspect(tree.span(), content="4")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(0)")
  inspect(tree.get_at(3).map(fn(t) { t.value }), content="Some(30)")
}

///|
test "insert_at 100 sequential items" {
  let tree : OrderTree[TItem] = OrderTree::new(min_degree=3)
  for i = 0; i < 100; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  inspect(tree.span(), content="100")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(0)")
  inspect(tree.get_at(50).map(fn(t) { t.value }), content="Some(50)")
  inspect(tree.get_at(99).map(fn(t) { t.value }), content="Some(99)")
}

///|
test "insert_at beyond span appends" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(1))
  tree.insert_at(100, ti(2)) // pos > span, should append
  inspect(tree.span(), content="2")
  inspect(tree.get_at(1).map(fn(t) { t.value }), content="Some(2)")
}

///|
test "delete_at from single-item tree" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(42))
  let deleted = tree.delete_at(0)
  inspect(deleted.map(fn(t) { t.value }), content="Some(42)")
  inspect(tree.is_empty(), content="true")
}

///|
test "delete_at from beginning" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let deleted = tree.delete_at(0)
  inspect(deleted.map(fn(t) { t.value }), content="Some(0)")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(1)")
  inspect(tree.span(), content="4")
}

///|
test "delete_at from end" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let deleted = tree.delete_at(4)
  inspect(deleted.map(fn(t) { t.value }), content="Some(4)")
  inspect(tree.span(), content="4")
}

///|
test "delete_at from middle" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let deleted = tree.delete_at(2)
  inspect(deleted.map(fn(t) { t.value }), content="Some(2)")
  inspect(tree.get_at(2).map(fn(t) { t.value }), content="Some(3)")
  inspect(tree.span(), content="4")
}

///|
test "delete_at triggers underflow and borrow/merge" {
  let tree : OrderTree[TItem] = OrderTree::new(min_degree=2)
  for i = 0; i < 7; i = i + 1 {
    tree.insert_at(i, ti(i * 10))
  }
  // Delete enough to trigger underflow
  for i = 0; i < 5; i = i + 1 {
    ignore(tree.delete_at(0))
  }
  inspect(tree.span(), content="2")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(50)")
  inspect(tree.get_at(1).map(fn(t) { t.value }), content="Some(60)")
}

///|
test "delete_at out of bounds returns None" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(1))
  inspect(tree.delete_at(5), content="None")
  inspect(tree.delete_at(-1), content="None")
  inspect(tree.span(), content="1")
}

///|
test "delete all items one by one" {
  let tree : OrderTree[TItem] = OrderTree::new(min_degree=2)
  for i = 0; i < 20; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  for i = 0; i < 20; i = i + 1 {
    let deleted = tree.delete_at(0)
    inspect(deleted.map(fn(t) { t.value }) == Some(i), content="true")
  }
  inspect(tree.is_empty(), content="true")
}

///|
test "set_at replaces item" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let old = tree.set_at(2, ti(99))
  inspect(old.map(fn(t) { t.value }), content="Some(2)")
  inspect(tree.get_at(2).map(fn(t) { t.value }), content="Some(99)")
  inspect(tree.span(), content="5")
}

///|
test "set_at out of bounds returns None" {
  let tree : OrderTree[TItem] = OrderTree::new()
  tree.insert_at(0, ti(1))
  inspect(tree.set_at(5, ti(99)), content="None")
}

///|
test "delete_range removes contiguous items" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 10; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  tree.delete_range(3, 7)
  inspect(tree.span(), content="6")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(0)")
  inspect(tree.get_at(2).map(fn(t) { t.value }), content="Some(2)")
  inspect(tree.get_at(3).map(fn(t) { t.value }), content="Some(7)")
}

///|
test "delete_range empty range does nothing" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  tree.delete_range(2, 2)
  inspect(tree.span(), content="5")
}

///|
test "to_array returns items in order" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let arr = tree.to_array()
  inspect(arr.length(), content="5")
  for i = 0; i < 5; i = i + 1 {
    inspect(arr[i].value == i, content="true")
  }
}

///|
test "each visits all items" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let result : Array[Int] = []
  tree.each(fn(item) { result.push(item.value) })
  inspect(result, content="[0, 1, 2, 3, 4]")
}

///|
test "iter collects items" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  let result = tree.iter().map(fn(t) { t.value }).collect()
  inspect(result, content="[0, 1, 2, 3, 4]")
}

///|
test "iter on empty tree" {
  let tree : OrderTree[TItem] = OrderTree::new()
  let result = tree.iter().collect()
  inspect(result.length(), content="0")
}

///|
test "from_array empty" {
  let tree : OrderTree[TItem] = OrderTree::from_array([])
  inspect(tree.is_empty(), content="true")
  inspect(tree.span(), content="0")
}

///|
test "from_array single item" {
  let tree = OrderTree::from_array([ti(42)])
  inspect(tree.span(), content="1")
  inspect(tree.get_at(0).map(fn(t) { t.value }), content="Some(42)")
}

///|
test "from_array 10 items" {
  let items = Array::makei(10, fn(i) { ti(i) })
  let tree = OrderTree::from_array(items)
  inspect(tree.span(), content="10")
  for i = 0; i < 10; i = i + 1 {
    inspect(tree.get_at(i).map(fn(t) { t.value }) == Some(i), content="true")
  }
}

///|
test "from_array roundtrip" {
  let items = Array::makei(100, fn(i) { ti(i) })
  let tree = OrderTree::from_array(items)
  inspect(tree.span(), content="100")
  inspect(tree.size(), content="100")
  let arr = tree.to_array()
  for i = 0; i < 100; i = i + 1 {
    inspect(arr[i].value == i, content="true")
  }
}

///|
test "from_array with small min_degree" {
  let items = Array::makei(20, fn(i) { ti(i) })
  let tree = OrderTree::from_array(items, min_degree=2)
  inspect(tree.span(), content="20")
  for i = 0; i < 20; i = i + 1 {
    inspect(tree.get_at(i).map(fn(t) { t.value }) == Some(i), content="true")
  }
}

///|
test "from_array then delete works" {
  let tree = OrderTree::from_array(
    Array::makei(50, fn(i) { ti(i) }),
    min_degree=3,
  )
  ignore(tree.delete_at(25))
  inspect(tree.span(), content="49")
  inspect(tree.get_at(25).map(fn(t) { t.value }), content="Some(26)")
}

///|
test "from_array then insert works" {
  let tree = OrderTree::from_array(
    Array::makei(50, fn(i) { ti(i) }),
    min_degree=3,
  )
  tree.insert_at(25, ti(999))
  inspect(tree.span(), content="51")
  inspect(tree.get_at(25).map(fn(t) { t.value }), content="Some(999)")
}

///|
test "rle trait: HasLength and Spanning" {
  let tree : OrderTree[TItem] = OrderTree::new()
  // Empty: length and span are 0
  inspect(@rle.HasLength::length(tree), content="0")
  inspect(@rle.Spanning::span(tree), content="0")
  // After inserts
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  inspect(@rle.HasLength::length(tree), content="5")
  inspect(@rle.Spanning::span(tree), content="5")
  // Method call syntax also works
  inspect(tree.span(), content="5")
}

///|
test "index syntax: tree[pos] and tree[pos] = item" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  // Getter: tree[pos]
  inspect(tree[0].map(fn(t) { t.value }), content="Some(0)")
  inspect(tree[4].map(fn(t) { t.value }), content="Some(4)")
  inspect(tree[10], content="None")
  // Setter: tree[pos] = item
  tree[2] = ti(99)
  inspect(tree[2].map(fn(t) { t.value }), content="Some(99)")
  inspect(tree.span(), content="5")
}

///|
test "view operator: tree[start:end]" {
  let tree : OrderTree[TItem] = OrderTree::new()
  for i = 0; i < 10; i = i + 1 {
    tree.insert_at(i, ti(i))
  }
  // Full range
  let all = tree[:]
  inspect(all.length(), content="10")
  // Sub-range [2, 5)
  let sub = tree[2:5]
  inspect(sub.length(), content="3")
  inspect(sub[0].value, content="2")
  inspect(sub[2].value, content="4")
  // From start
  let head = tree[:3]
  inspect(head.length(), content="3")
  inspect(head[0].value, content="0")
  // From offset to end
  let tail = tree[7:]
  inspect(tail.length(), content="3")
  inspect(tail[0].value, content="7")
  // Empty range
  let empty = tree[5:5]
  inspect(empty.length(), content="0")
}

// ====================================================================
// Mergeable test type for RLE-specific tests
// ====================================================================

///|
/// A test type that merges when values are consecutive.
priv struct MItem {
  start : Int
  count : Int
} derive(Show)

///|
impl @rle.HasLength for MItem with length(self) -> Int {
  self.count
}

///|
impl @rle.Spanning for MItem with span(self) -> Int {
  self.count
}

///|
impl @rle.Mergeable for MItem with can_merge(self, other) -> Bool {
  self.start + self.count == other.start
}

///|
impl @rle.Mergeable for MItem with merge(self, other) -> MItem {
  { start: self.start, count: self.count + other.count }
}

///|
impl @rle.Sliceable for MItem with slice(self, start~ : Int, end~ : Int) -> Result[
  MItem,
  @rle.RleError,
] {
  if start < 0 || end > self.count || start >= end {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  } else {
    Ok({ start: self.start + start, count: end - start })
  }
}

///|
fn mi(start : Int) -> MItem {
  { start, count: 1 }
}

///|
fn mr(start : Int, count : Int) -> MItem {
  { start, count }
}

// ====================================================================
// RLE merge-on-insert tests
// ====================================================================

///|
test "merge on sequential insert" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mi(0))
  tree.insert_at(1, mi(1))
  tree.insert_at(2, mi(2))
  inspect(tree.size(), content="1") // All merged into one leaf
  inspect(tree.span(), content="3")
}

///|
test "no merge on non-consecutive insert" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mi(0))
  tree.insert_at(1, mi(5)) // Not consecutive — no merge
  inspect(tree.size(), content="2")
}

///|
test "merge on boundary insert" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 3)) // [0..3)
  tree.insert_at(3, mr(3, 2)) // [0..5) — merged
  inspect(tree.size(), content="1")
  inspect(tree.span(), content="5")
}

// ====================================================================
// RLE split-on-insert tests
// ====================================================================

///|
test "split on mid-run insert" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 5)) // [0..5)
  tree.insert_at(2, mi(100)) // Split [0..5) at 2 → [0..2), [100], [2..5)
  inspect(tree.span(), content="6")
  // Position 0 → start=0
  // Position 2 → start=100
  // Position 3 → start=2
  inspect(tree.find(0).unwrap().elem.start, content="0")
  inspect(tree.find(2).unwrap().elem.start, content="100")
  inspect(tree.find(3).unwrap().elem.start, content="2")
}

// ====================================================================
// RLE split-on-delete tests
// ====================================================================

///|
test "delete from middle of run" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 5)) // [0..5)
  let deleted = tree.delete_at(2) // Delete unit at pos 2 → [0..2), [3..5)
  inspect(deleted.unwrap().start, content="2")
  inspect(tree.span(), content="4")
}

///|
test "delete first unit of run" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 3))
  let deleted = tree.delete_at(0)
  inspect(deleted.unwrap().start, content="0")
  inspect(tree.span(), content="2")
  inspect(tree.find(0).unwrap().elem.start, content="1")
}

///|
test "delete last unit of run" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 3))
  let deleted = tree.delete_at(2)
  inspect(deleted.unwrap().start, content="2")
  inspect(tree.span(), content="2")
  inspect(tree.find(1).unwrap().elem.start, content="0")
}

// ====================================================================
// RLE from_array tests
// ====================================================================

///|
test "from_array merges consecutive items" {
  let items = [mi(0), mi(1), mi(2), mi(5), mi(6)]
  let tree = OrderTree::from_array(items, min_degree=3)
  inspect(tree.size(), content="2") // [0..3) and [5..7)
  inspect(tree.span(), content="5")
}

///|
test "from_array filters zero-span" {
  let items = [mr(0, 0), mi(1), mr(2, 0), mi(2)]
  let tree = OrderTree::from_array(items, min_degree=3)
  inspect(tree.size(), content="1") // [1..3) after filter + merge
  inspect(tree.span(), content="2")
}

// ====================================================================
// RLE view tests
// ====================================================================

///|
test "view slices at boundaries" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 10))
  let v = tree.view(start=3, end=7)
  inspect(v.length(), content="1")
  inspect(v[0].start, content="3")
  inspect(v[0].count, content="4")
}

///|
test "same-run delete_range with mergeable type" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  tree.insert_at(0, mr(0, 10)) // [0..10)
  tree.delete_range(3, 7) // Delete positions 3-6 → [0..3) and [7..10)
  inspect(@rle.Spanning::span(tree), content="6")
  // First element should be [0..3)
  let fr0 = tree.find(0).unwrap()
  inspect(fr0.elem.start, content="0")
  inspect(fr0.elem.count, content="3")
  // Second element should be [7..10)
  let fr3 = tree.find(3).unwrap()
  inspect(fr3.elem.start, content="7")
  inspect(fr3.elem.count, content="3")
}

// ====================================================================
// RLE round-trip tests
// ====================================================================

///|
test "round-trip: insert many then to_array" {
  let tree : OrderTree[MItem] = OrderTree::new(min_degree=3)
  for i = 0; i < 100; i = i + 1 {
    tree.insert_at(i, mi(i))
  }
  // All 100 consecutive items should merge
  inspect(tree.size(), content="1")
  let arr = tree.to_array()
  inspect(arr[0].start, content="0")
  inspect(arr[0].count, content="100")
}
