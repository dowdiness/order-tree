///|
priv struct WalkerItem {
  value : String
}

///|
priv struct Run {
  ch : String
  span : Int
} derive(Show)

///|
fn wi(value : String) -> WalkerItem {
  { value: value }
}

///|
fn run(ch : String, span : Int) -> Run {
  { ch, span }
}

///|
impl @rle.HasLength for Run with length(self : Run) -> Int {
  self.span
}

///|
impl @rle.Spanning for Run with span(self : Run) -> Int {
  self.span
}

///|
impl @rle.Mergeable for Run with can_merge(self : Run, other : Run) -> Bool {
  self.ch == other.ch
}

///|
impl @rle.Mergeable for Run with merge(self : Run, other : Run) -> Run {
  { ch: self.ch, span: self.span + other.span }
}

///|
impl @rle.Sliceable for Run with slice(
  self : Run,
  start~ : Int,
  end~ : Int,
) -> Result[Run, @rle.RleError] {
  if start < 0 || end < start || end > self.span {
    return Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
  Ok({ ch: self.ch, span: end - start })
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

///|
test "descend keeps insert boundary on current leaf" {
  let root : OrderNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 2), span=2),
      Leaf(elem=run("b", 2), span=2),
    ],
    counts=[2, 2],
    total=4,
  )
  match descend(root, 2, 2, prepare_noop, find_slot_inclusive, true) {
    None => inspect("missing cursor", content="\"unexpected\"")
    Some(cursor) => {
      inspect(cursor.child_idx, content="0")
      inspect(cursor.offset, content="2")
      inspect(cursor.leaf_elem, content="{ch: \"a\", span: 2}")
    }
  }
}

///|
test "descend re-finds slot after ensure-min merge" {
  let left : OrderNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 1), span=1),
      Leaf(elem=run("b", 1), span=1),
    ],
    counts=[1, 1],
    total=2,
  )
  let right : OrderNode[Run] = Internal(
    children=[
      Leaf(elem=run("c", 1), span=1),
      Leaf(elem=run("d", 1), span=1),
    ],
    counts=[1, 1],
    total=2,
  )
  let root : OrderNode[Run] = Internal(
    children=[left, right],
    counts=[2, 2],
    total=4,
  )
  match descend(root, 2, 2, prepare_ensure_min, find_slot, false) {
    None => inspect("missing cursor", content="\"unexpected\"")
    Some(cursor) => {
      inspect(cursor.path.length(), content="2")
      inspect(cursor.path[0].children.length(), content="1")
      inspect(cursor.child_idx, content="2")
      inspect(cursor.offset, content="0")
      inspect(cursor.leaf_elem, content="{ch: \"c\", span: 1}")
    }
  }
}

///|
test "propagate reports root overflow after splice expands full root" {
  let children : Array[OrderNode[Run]] = [
    Leaf(elem=run("a", 1), span=1),
    Leaf(elem=run("b", 1), span=1),
    Leaf(elem=run("c", 1), span=1),
    Leaf(elem=run("d", 1), span=1),
  ]
  let counts = [1, 1, 1, 1]
  let path : Array[PathFrame[Run]] = [{ children, counts, child_idx: 3 }]
  let result = propagate(
    path,
    { start_idx: 4, end_idx: 4, new_leaves: [(run("e", 1), 1)] },
    2,
    1,
  )
  inspect(result.leaf_delta, content="1")
  inspect(result.node.total(), content="2")
  inspect(result.overflow.map(fn(node) { node.total() }), content="Some(3)")
}

///|
test "delete_at collapses root after propagated child removal" {
  let tree : OrderTree[Run] = OrderTree::new(min_degree=2)
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, run((i + 1).to_string(), 1))
  }
  ignore(tree.delete_at(0))
  ignore(tree.delete_at(0))
  ignore(tree.delete_at(0))
  inspect(tree.span(), content="2")
  inspect(tree.find(0).map(fn(fr) { fr.elem }), content="Some({ch: \"4\", span: 1})")
  inspect(tree.find(1).map(fn(fr) { fr.elem }), content="Some({ch: \"5\", span: 1})")
  match tree.root {
    Some(Internal(children~, ..)) => inspect(children.length(), content="2")
    _ => inspect("bad root", content="\"unexpected\"")
  }
}
