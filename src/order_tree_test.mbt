///|
priv struct TItem {
  value : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for TItem with length(_self) -> Int { 1 }

///|
impl @rle.Spanning for TItem with span(_self) -> Int { 1 }

///|
fn ti(v : Int) -> TItem { { value: v } }

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
