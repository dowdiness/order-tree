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

// === Tests for order-tree-local range delete logic ===

///|
test "shared prefix length handles same leaf and divergence" {
  let root : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 1), span=1), Leaf(elem=run("b", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let left = @btree.descend_leaf_at(root, 0, 2).unwrap()
  let right = @btree.descend_leaf_at(root, 1, 2).unwrap()
  inspect(shared_prefix_length(left.path, left.path), content="1")
  inspect(shared_prefix_length(left.path, right.path), content="0")
}

///|
test "lowest common ancestor range handles same leaf" {
  let root : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("b", 2), span=2)],
    counts=[3, 2],
    total=5,
  )
  let start = @btree.descend_leaf_at(root, 1, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 2, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="1")
  inspect(range.child_height, content="0")
}

///|
test "lowest common ancestor range handles same parent different children" {
  let root : BTreeNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 2), span=2),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("c", 2), span=2),
    ],
    counts=[2, 2, 2],
    total=6,
  )
  let start = @btree.descend_leaf_at(root, 1, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 5, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="3")
  inspect(range.child_height, content="0")
}

///|
test "lowest common ancestor range handles higher level divergence" {
  let left_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 1), span=1), Leaf(elem=run("b", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let right_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("c", 1), span=1), Leaf(elem=run("d", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let root : BTreeNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[2, 2],
    total=4,
  )
  let start = @btree.descend_leaf_at(root, 1, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 3, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="2")
  inspect(range.child_height, content="1")
}

///|
test "left boundary subtree returns none when start is on leaf boundary" {
  let root : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let start = @btree.descend_leaf_at(root, 2, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  inspect(left_boundary_subtree(lca, start) is None, content="true")
}

///|
test "right boundary subtree returns none when end is on leaf boundary" {
  let root : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let start = @btree.descend_leaf_at(root, 1, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 2, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  inspect(right_boundary_subtree(lca, end_) is None, content="true")
}

///|
test "left boundary subtree rebuilds to lca child height" {
  let left_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 1), span=1)],
    counts=[2, 1],
    total=3,
  )
  let right_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("c", 2), span=2)],
    counts=[2],
    total=2,
  )
  let root : BTreeNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[3, 2],
    total=5,
  )
  let start = @btree.descend_leaf_at(root, 1, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  let rebuilt = left_boundary_subtree(lca, start).unwrap()
  inspect(rebuilt.height(), content="1")
  inspect(rebuilt.total(), content="1")
}

///|
test "right boundary subtree rebuilds to lca child height" {
  let left_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2)],
    counts=[2],
    total=2,
  )
  let right_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("b", 1), span=1), Leaf(elem=run("c", 2), span=2)],
    counts=[1, 2],
    total=3,
  )
  let root : BTreeNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[2, 3],
    total=5,
  )
  let start = @btree.descend_leaf_at(root, 0, 2).unwrap()
  let end_ = @btree.descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  let rebuilt = right_boundary_subtree(lca, end_).unwrap()
  inspect(rebuilt.height(), content="1")
  inspect(rebuilt.total(), content="1")
}

///|
test "plan delete range handles same leaf splice" {
  let root : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 5), span=5), Leaf(elem=run("b", 2), span=2)],
    counts=[5, 2],
    total=7,
  )
  let splice = plan_delete_range(root, 1, 4, 2).unwrap()
  inspect(splice.prefix.length(), content="0")
  inspect(splice.start_idx, content="0")
  inspect(splice.end_idx, content="1")
  inspect(splice.new_children.length(), content="1")
  inspect(splice.new_children[0].total(), content="2")
  inspect(splice.leaf_delta, content="0")
}

///|
test "plan delete range handles multi child lca splice" {
  let root : BTreeNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 2), span=2),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("c", 2), span=2),
    ],
    counts=[2, 2, 2],
    total=6,
  )
  let splice = plan_delete_range(root, 1, 5, 2).unwrap()
  inspect(splice.prefix.length(), content="0")
  inspect(splice.start_idx, content="0")
  inspect(splice.end_idx, content="3")
  inspect(splice.new_children.length(), content="2")
  inspect(splice.new_children[0].height(), content="0")
  inspect(splice.new_children[0].total(), content="1")
  inspect(splice.new_children[1].height(), content="0")
  inspect(splice.new_children[1].total(), content="1")
  inspect(splice.leaf_delta, content="-1")
}

///|
test "plan delete range merges partial kept boundaries in same parent" {
  let root : BTreeNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 3), span=3),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("a", 2), span=2),
    ],
    counts=[3, 2, 2],
    total=7,
  )
  let splice = plan_delete_range(root, 1, 6, 2).unwrap()
  inspect(splice.new_children.length(), content="1")
  inspect(splice.new_children[0].height(), content="0")
  inspect(splice.new_children[0].total(), content="2")
  inspect(splice.leaf_delta, content="-2")
}

///|
test "plan delete range merges partial kept boundaries across higher lca" {
  let left_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("b", 2), span=2)],
    counts=[3, 2],
    total=5,
  )
  let right_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("c", 2), span=2), Leaf(elem=run("a", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let root : BTreeNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[5, 4],
    total=9,
  )
  let splice = plan_delete_range(root, 1, 8, 2).unwrap()
  inspect(splice.prefix.length(), content="0")
  inspect(splice.start_idx, content="0")
  inspect(splice.end_idx, content="2")
  inspect(splice.new_children.length(), content="1")
  inspect(splice.new_children[0].height(), content="1")
  inspect(splice.new_children[0].total(), content="2")
  inspect(splice.leaf_delta, content="-3")
}

///|
test "plan delete range keeps split partial boundaries when not mergeable" {
  let root : BTreeNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 3), span=3),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("c", 2), span=2),
    ],
    counts=[3, 2, 2],
    total=7,
  )
  let splice = plan_delete_range(root, 1, 6, 2).unwrap()
  inspect(splice.new_children.length(), content="2")
  inspect(splice.new_children[0].total(), content="1")
  inspect(splice.new_children[1].total(), content="1")
}

///|
test "plan delete range absorbs exact leaf-level gap merge" {
  let root : BTreeNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 3), span=3),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("a", 2), span=2),
    ],
    counts=[3, 2, 2],
    total=7,
  )
  let splice = plan_delete_range(root, 3, 5, 2).unwrap()
  inspect(splice.start_idx, content="0")
  inspect(splice.end_idx, content="3")
  inspect(splice.new_children.length(), content="1")
  inspect(splice.new_children[0].total(), content="5")
  inspect(splice.leaf_delta, content="-2")
}

///|
test "plan delete range absorbs exact higher-level gap merge" {
  let left_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("x", 1), span=1), Leaf(elem=run("a", 2), span=2)],
    counts=[1, 2],
    total=3,
  )
  let middle_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("b", 2), span=2)],
    counts=[2],
    total=2,
  )
  let right_child : BTreeNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("y", 1), span=1)],
    counts=[3, 1],
    total=4,
  )
  let root : BTreeNode[Run] = Internal(
    children=[left_child, middle_child, right_child],
    counts=[3, 2, 4],
    total=9,
  )
  let splice = plan_delete_range(root, 3, 5, 2).unwrap()
  inspect(splice.start_idx, content="0")
  inspect(splice.end_idx, content="3")
  inspect(splice.new_children.length(), content="1")
  inspect(splice.new_children[0].height(), content="1")
  inspect(splice.new_children[0].total(), content="7")
  inspect(splice.leaf_delta, content="-2")
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
