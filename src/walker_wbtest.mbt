///|
priv struct WalkerItem {
  value : String
}

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
fn wi(value : String) -> WalkerItem {
  { value, }
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
test "cursor as leaf preserves leaf payload" {
  let cursor : Cursor[Run] = {
    path: [],
    leaf_elem: run("x", 3),
    leaf_span: 3,
    offset: 1,
    child_idx: 0,
  }
  let leaf = cursor_as_leaf(cursor).unwrap()
  inspect(
    leaf.elem,
    content=(
      #|{ ch: "x", span: 3 }
    ),
  )
  inspect(leaf.span, content="3")
  inspect(leaf.offset, content="1")
}

///|
test "descend keeps insert boundary on current leaf" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  match descend(root, 2, 2, prepare_noop, find_slot_inclusive, true) {
    None => inspect("missing cursor", content="\"unexpected\"")
    Some(cursor) => {
      inspect(cursor.child_idx, content="0")
      inspect(cursor.offset, content="2")
      inspect(
        cursor.leaf_elem,
        content=(
          #|{ ch: "a", span: 2 }
        ),
      )
    }
  }
}

///|
test "descend leaf at uses strict boundary semantics" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let leaf = descend_leaf_at(root, 2, 2).unwrap()
  inspect(
    leaf.elem,
    content=(
      #|{ ch: "b", span: 2 }
    ),
  )
  inspect(leaf.offset, content="0")
}

///|
test "descend leaf at end boundary stays on left leaf" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 3), span=3)],
    counts=[2, 3],
    total=5,
  )
  let boundary = descend_leaf_at_end_boundary(root, 2, 2).unwrap()
  inspect(
    boundary.elem,
    content=(
      #|{ ch: "a", span: 2 }
    ),
  )
  inspect(boundary.offset, content="2")
  let end_of_tree = descend_leaf_at_end_boundary(root, 5, 2).unwrap()
  inspect(
    end_of_tree.elem,
    content=(
      #|{ ch: "b", span: 3 }
    ),
  )
  inspect(end_of_tree.offset, content="3")
}

///|
test "descend leaf at end boundary returns none at tree start" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 3), span=3)],
    counts=[2, 3],
    total=5,
  )
  inspect(descend_leaf_at_end_boundary(root, 0, 2) is None, content="true")
}

///|
test "order node height counts edges to leaf" {
  let leaf : OrderNode[Run] = Leaf(elem=run("a", 1), span=1)
  let child : OrderNode[Run] = Internal(children=[leaf], counts=[1], total=1)
  let root : OrderNode[Run] = Internal(children=[child], counts=[1], total=1)
  inspect(leaf.height(), content="0")
  inspect(child.height(), content="1")
  inspect(root.height(), content="2")
}

///|
test "shared prefix length handles same leaf and divergence" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 1), span=1), Leaf(elem=run("b", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let left = descend_leaf_at(root, 0, 2).unwrap()
  let right = descend_leaf_at(root, 1, 2).unwrap()
  inspect(shared_prefix_length(left.path, left.path), content="1")
  inspect(shared_prefix_length(left.path, right.path), content="0")
}

///|
test "lowest common ancestor range handles same leaf" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("b", 2), span=2)],
    counts=[3, 2],
    total=5,
  )
  let start = descend_leaf_at(root, 1, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 2, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="1")
  inspect(range.child_height, content="0")
}

///|
test "lowest common ancestor range handles same parent different children" {
  let root : OrderNode[Run] = Internal(
    children=[
      Leaf(elem=run("a", 2), span=2),
      Leaf(elem=run("b", 2), span=2),
      Leaf(elem=run("c", 2), span=2),
    ],
    counts=[2, 2, 2],
    total=6,
  )
  let start = descend_leaf_at(root, 1, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 5, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="3")
  inspect(range.child_height, content="0")
}

///|
test "lowest common ancestor range handles higher level divergence" {
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 1), span=1), Leaf(elem=run("b", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("c", 1), span=1), Leaf(elem=run("d", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let root : OrderNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[2, 2],
    total=4,
  )
  let start = descend_leaf_at(root, 1, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 3, 2).unwrap()
  let range = lowest_common_ancestor_range(start, end_)
  inspect(range.prefix.length(), content="0")
  inspect(range.start_idx, content="0")
  inspect(range.end_idx, content="2")
  inspect(range.child_height, content="1")
}

///|
test "left boundary subtree returns none when start is on leaf boundary" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let start = descend_leaf_at(root, 2, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  inspect(left_boundary_subtree(lca, start) is None, content="true")
}

///|
test "right boundary subtree returns none when end is on leaf boundary" {
  let root : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let start = descend_leaf_at(root, 1, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 2, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  inspect(right_boundary_subtree(lca, end_) is None, content="true")
}

///|
test "left boundary subtree rebuilds to lca child height" {
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 1), span=1)],
    counts=[2, 1],
    total=3,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("c", 2), span=2)],
    counts=[2],
    total=2,
  )
  let root : OrderNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[3, 2],
    total=5,
  )
  let start = descend_leaf_at(root, 1, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  let rebuilt = left_boundary_subtree(lca, start).unwrap()
  inspect(rebuilt.height(), content="1")
  inspect(rebuilt.total(), content="1")
}

///|
test "right boundary subtree rebuilds to lca child height" {
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2)],
    counts=[2],
    total=2,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("b", 1), span=1), Leaf(elem=run("c", 2), span=2)],
    counts=[1, 2],
    total=3,
  )
  let root : OrderNode[Run] = Internal(
    children=[left_child, right_child],
    counts=[2, 3],
    total=5,
  )
  let start = descend_leaf_at(root, 0, 2).unwrap()
  let end_ = descend_leaf_at_end_boundary(root, 4, 2).unwrap()
  let lca = lowest_common_ancestor_range(start, end_)
  let rebuilt = right_boundary_subtree(lca, end_).unwrap()
  inspect(rebuilt.height(), content="1")
  inspect(rebuilt.total(), content="1")
}

///|
test "plan delete range handles same leaf splice" {
  let root : OrderNode[Run] = Internal(
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
  let root : OrderNode[Run] = Internal(
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
  let root : OrderNode[Run] = Internal(
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
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("b", 2), span=2)],
    counts=[3, 2],
    total=5,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("c", 2), span=2), Leaf(elem=run("a", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let root : OrderNode[Run] = Internal(
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
  let root : OrderNode[Run] = Internal(
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
  let root : OrderNode[Run] = Internal(
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
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("x", 1), span=1), Leaf(elem=run("a", 2), span=2)],
    counts=[1, 2],
    total=3,
  )
  let middle_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("b", 2), span=2)],
    counts=[2],
    total=2,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 3), span=3), Leaf(elem=run("y", 1), span=1)],
    counts=[3, 1],
    total=4,
  )
  let root : OrderNode[Run] = Internal(
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
test "propagate node splice updates root in place" {
  let children : Array[OrderNode[Run]] = [
    Leaf(elem=run("a", 2), span=2),
    Leaf(elem=run("b", 2), span=2),
    Leaf(elem=run("c", 2), span=2),
  ]
  let counts = [2, 2, 2]
  let result = propagate_node_splice(
    {
      prefix: [],
      children,
      counts,
      start_idx: 0,
      end_idx: 3,
      new_children: [
        Leaf(elem=run("a", 1), span=1),
        Leaf(elem=run("c", 1), span=1),
      ],
      original_child_count: 3,
      leaf_delta: -1,
    },
    2,
  )
  inspect(result.node.total(), content="2")
  inspect(result.overflow is None, content="true")
  inspect(result.leaf_delta, content="-1")
  match result.node {
    Internal(children~, counts~, total~) => {
      inspect(children.length(), content="2")
      inspect(counts, content="[1, 1]")
      inspect(total, content="2")
    }
    _ => inspect("bad node", content="\"unexpected\"")
  }
}

///|
test "propagate node splice updates ancestor counts" {
  let left_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 2), span=2), Leaf(elem=run("b", 2), span=2)],
    counts=[2, 2],
    total=4,
  )
  let right_child : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("c", 3), span=3)],
    counts=[3],
    total=3,
  )
  let root_children : Array[OrderNode[Run]] = [left_child, right_child]
  let root_counts = [4, 3]
  let prefix : Array[PathFrame[Run]] = [
    { children: root_children, counts: root_counts, child_idx: 0 },
  ]
  let target_children : Array[OrderNode[Run]] = [
    Leaf(elem=run("a", 2), span=2),
    Leaf(elem=run("b", 2), span=2),
  ]
  let target_counts = [2, 2]
  let result = propagate_node_splice(
    {
      prefix,
      children: target_children,
      counts: target_counts,
      start_idx: 0,
      end_idx: 2,
      new_children: [Leaf(elem=run("a", 1), span=1)],
      original_child_count: 2,
      leaf_delta: -1,
    },
    2,
  )
  inspect(result.overflow is None, content="true")
  inspect(result.node.total(), content="4")
  match result.node {
    Internal(children~, counts~, total~) => {
      inspect(children.length(), content="2")
      inspect(counts, content="[1, 3]")
      inspect(total, content="4")
    }
    _ => inspect("bad node", content="\"unexpected\"")
  }
}

///|
test "descend re-finds slot after ensure-min merge" {
  let left : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("a", 1), span=1), Leaf(elem=run("b", 1), span=1)],
    counts=[1, 1],
    total=2,
  )
  let right : OrderNode[Run] = Internal(
    children=[Leaf(elem=run("c", 1), span=1), Leaf(elem=run("d", 1), span=1)],
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
      inspect(
        cursor.leaf_elem,
        content=(
          #|{ ch: "c", span: 1 }
        ),
      )
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
  match tree.root {
    Some(Internal(children~, ..)) => inspect(children.length(), content="2")
    _ => inspect("bad root", content="\"unexpected\"")
  }
}
