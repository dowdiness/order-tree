///|
priv struct Run {
  ch : String
  span : Int
} derive(Debug)

///|

///|
fn run(ch : String, span : Int) -> Run {
  { ch, span }
}

///|
impl @rle.HasLength for Run with fn length(self : Run) -> Int {
  self.span
}

///|
impl @rle.Spanning for Run with fn span(self : Run) -> Int {
  self.span
}

///|
impl @rle.Mergeable for Run with fn can_merge(self : Run, other : Run) -> Bool {
  self.ch == other.ch
}

///|
impl @rle.Mergeable for Run with fn merge(self : Run, other : Run) -> Run {
  { ch: self.ch, span: self.span + other.span }
}

///|
impl @rle.Sliceable for Run with fn slice(self : Run, start~ : Int, end~ : Int) -> Result[
  Run,
  @rle.RleError,
] {
  if start < 0 || end < start || end > self.span {
    return Err(
      @rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex),
    )
  }
  Ok({ ch: self.ch, span: end - start })
}

///|
impl @btree.BTreeElem for Run

// === Tests for order-tree-specific behavior ===

///|
test "insert_at normalizes a cross-parent right boundary" {
  let tree = OrderTree::from_array(
    [run("a", 1), run("b", 1), run("c", 1), run("d", 1), run("e", 1)],
    min_degree=2,
  )
  tree.insert_at(2, run("c", 1))
  @debug.debug_inspect(tree.size(), content="5")
  @debug.debug_inspect(tree.span(), content="6")
  @debug.debug_inspect(
    tree.to_array().map(item => (item.ch, item.span)),
    content=(
      #|[("a", 1), ("b", 1), ("c", 2), ("d", 1), ("e", 1)]
    ),
  )
}

///|
test "insert_at normalizes a cross-parent left boundary" {
  let tree = OrderTree::from_array(
    [run("a", 1), run("b", 1), run("c", 1), run("d", 1), run("e", 1)],
    min_degree=2,
  )
  tree.insert_at(2, run("b", 1))
  @debug.debug_inspect(tree.size(), content="5")
  @debug.debug_inspect(
    tree.to_array().map(item => (item.ch, item.span)),
    content=(
      #|[("a", 1), ("b", 2), ("c", 1), ("d", 1), ("e", 1)]
    ),
  )
}

///|
test "insert_at preserves a stable cross-parent boundary" {
  let tree = OrderTree::from_array(
    [run("a", 1), run("b", 1), run("c", 1), run("d", 1), run("e", 1)],
    min_degree=2,
  )
  tree.insert_at(2, run("x", 1))
  @debug.debug_inspect(tree.size(), content="6")
  @debug.debug_inspect(
    tree.to_array().map(item => (item.ch, item.span)),
    content=(
      #|[("a", 1), ("b", 1), ("x", 1), ("c", 1), ("d", 1), ("e", 1)]
    ),
  )
}

///|
test "delete_at normalizes a newly exposed cross-parent boundary" {
  let tree = OrderTree::from_array(
    [run("a", 1), run("b", 1), run("c", 1), run("b", 1), run("e", 1)],
    min_degree=2,
  )
  let deleted = tree.delete_at(2)
  @debug.debug_inspect(
    deleted.map(item => (item.ch, item.span)),
    content="Some((\"c\", 1))",
  )
  @debug.debug_inspect(tree.size(), content="3")
  @debug.debug_inspect(tree.span(), content="4")
  @debug.debug_inspect(
    tree.to_array().map(item => (item.ch, item.span)),
    content=(
      #|[("a", 1), ("b", 2), ("e", 1)]
    ),
  )
}

///|
test "set_at reuses cross-parent delete and insert normalization" {
  let tree = OrderTree::from_array(
    [run("a", 1), run("b", 1), run("c", 1), run("b", 1), run("e", 1)],
    min_degree=2,
  )
  let replaced = tree.set_at(2, run("b", 1))
  @debug.debug_inspect(
    replaced.map(item => (item.ch, item.span)),
    content="Some((\"c\", 1))",
  )
  @debug.debug_inspect(tree.size(), content="3")
  @debug.debug_inspect(tree.span(), content="5")
  @debug.debug_inspect(
    tree.to_array().map(item => (item.ch, item.span)),
    content=(
      #|[("a", 1), ("b", 3), ("e", 1)]
    ),
  )
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
  @debug.debug_inspect(tree.span(), content="2")
  @debug.debug_inspect(
    tree.find(0).map(fn(fr) { fr.elem }),
    content=(
      #|Some({ ch: "4", span: 1 })
    ),
  )
  @debug.debug_inspect(
    tree.find(1).map(fn(fr) { fr.elem }),
    content=(
      #|Some({ ch: "5", span: 1 })
    ),
  )
}
