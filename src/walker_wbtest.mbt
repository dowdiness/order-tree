///|
priv struct WalkerItem {
  value : String
}

///|
fn wi(value : String) -> WalkerItem {
  { value: value }
}

///|
test "leaf context neighbor access" {
  let children : Array[OrderNode[WalkerItem]] = [
    Leaf(elem=wi("aa"), span=2),
    Leaf(elem=wi("bbb"), span=3),
    Leaf(elem=wi("c"), span=1),
  ]
  let counts = [2, 3, 1]
  let cursor : Cursor[WalkerItem] = {
    path: [{ children, counts, child_idx: 1 }],
    leaf_elem: wi("bbb"),
    leaf_span: 3,
    offset: 1,
    child_idx: 1,
  }
  let ctx = LeafContext::from_cursor(cursor)
  inspect(ctx.left_neighbor().map(fn(x) { x.value }), content="Some(\"aa\")")
  inspect(ctx.right_neighbor().map(fn(x) { x.value }), content="Some(\"c\")")
}

///|
test "find slot helpers preserve boundary semantics" {
  let counts = [3, 5, 2]
  inspect(find_slot(counts, 3, 10), content="(1, 0)")
  inspect(find_slot(counts, 8, 10), content="(2, 0)")
  inspect(find_slot_inclusive(counts, 3, 10), content="(0, 3)")
  inspect(find_slot_inclusive(counts, 10, 10), content="(2, 2)")
}
