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
