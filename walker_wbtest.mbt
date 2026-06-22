///|
priv struct Run {
  ch : String
  span : Int
} derive(Debug)

///|
impl Show for Run with output(self, logger) {
  logger.write_string(@debug.to_string(self))
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
impl @rle.Sliceable for Run with slice(self : Run, start~ : Int, end~ : Int) -> Result[
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
test "delete_at collapses root after propagated child removal" {
  let tree : OrderTree[Run] = OrderTree::new(min_degree=2)
  for i = 0; i < 5; i = i + 1 {
    tree.insert_at(i, run((i + 1).to_string(), 1))
  }
  ignore(tree.delete_at(0))
  ignore(tree.delete_at(0))
  ignore(tree.delete_at(0))
  inspect(tree.span(), content="2")
  inspect(
    tree.find(0).map(fn(fr) { fr.elem }),
    content=(
      #|Some({ ch: "4", span: 1 })
    ),
  )
  inspect(
    tree.find(1).map(fn(fr) { fr.elem }),
    content=(
      #|Some({ ch: "5", span: 1 })
    ),
  )
  match tree.tree.root {
    Some(Internal(children~, ..)) => inspect(children.length(), content="2")
    _ => inspect("bad root", content="\"unexpected\"")
  }
}
