///|
priv struct TItem {
  value : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for TItem with length(_self) -> Int {
  1
}

///|
impl @rle.Spanning for TItem with span(_self) -> Int {
  1
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
