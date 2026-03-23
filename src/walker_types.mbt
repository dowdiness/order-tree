///|
/// Walker contract:
/// - descent owns navigation and may mutate internal nodes via prepare hooks
/// - leaf actions read `LeafContext` and return pure `Splice` descriptions
/// - propagation is the only phase that rewrites ancestors and handles splits
/// One frame of the descent path from root to the focused leaf.
priv struct PathFrame[T] {
  children : Array[OrderNode[T]]
  counts : Array[Int]
  child_idx : Int
}

///|
/// A cursor pointing at a leaf together with its ancestor path.
priv struct Cursor[T] {
  path : Array[PathFrame[T]]
  leaf_elem : T
  leaf_span : Int
  offset : Int
  child_idx : Int
}

///|
/// Leaf-specialized cursor used by range planners.
priv struct LeafCursor[T] {
  path : Array[PathFrame[T]]
  elem : T
  span : Int
  offset : Int
}

///|
/// Lowest-common-ancestor interval targeted by a range splice.
priv struct AncestorRange[T] {
  prefix : Array[PathFrame[T]]
  children : Array[OrderNode[T]]
  counts : Array[Int]
  start_idx : Int
  end_idx : Int
  child_height : Int
}

///|
/// General subtree splice at the LCA child height.
priv struct NodeSplice[T] {
  prefix : Array[PathFrame[T]]
  children : Array[OrderNode[T]]
  counts : Array[Int]
  start_idx : Int
  end_idx : Int
  new_children : Array[OrderNode[T]]
  original_child_count : Int
  leaf_delta : Int
}

///|
/// Read-only context passed to pure leaf splice computations.
priv struct LeafContext[T] {
  elem : T
  span : Int
  offset : Int
  children : Array[OrderNode[T]]
  child_idx : Int
}

///|
/// Declarative replacement of children[start_idx..end_idx) with new leaves.
priv struct Splice[T] {
  start_idx : Int
  end_idx : Int
  new_leaves : Array[(T, Int)]
}

///|
priv struct InsertLeafResult[T] {
  splice : Splice[T]
  leaf_delta : Int
}

///|
priv struct DeleteLeafResult[T] {
  splice : Splice[T]
  deleted : T
  leaf_delta : Int
}

///|
priv struct PropagateResult[T] {
  node : OrderNode[T]
  overflow : OrderNode[T]?
  leaf_delta : Int
}

///|
fn[T] LeafContext::left_neighbor(self : LeafContext[T]) -> T? {
  if self.child_idx == 0 {
    return None
  }
  match self.children[self.child_idx - 1] {
    Leaf(elem~, ..) => Some(elem)
    Internal(..) => None
  }
}

///|
fn[T] LeafContext::right_neighbor(self : LeafContext[T]) -> T? {
  if self.child_idx + 1 >= self.children.length() {
    return None
  }
  match self.children[self.child_idx + 1] {
    Leaf(elem~, ..) => Some(elem)
    Internal(..) => None
  }
}

///|
fn[T] LeafContext::from_cursor(cursor : Cursor[T]) -> LeafContext[T] {
  if cursor.path.length() == 0 {
    abort("LeafContext::from_cursor: cursor missing parent frame")
  }
  let frame = cursor.path[cursor.path.length() - 1]
  {
    elem: cursor.leaf_elem,
    span: cursor.leaf_span,
    offset: cursor.offset,
    children: frame.children,
    child_idx: cursor.child_idx,
  }
}

///|
fn[T] LeafCursor::from_cursor(cursor : Cursor[T]) -> LeafCursor[T] {
  {
    path: cursor.path,
    elem: cursor.leaf_elem,
    span: cursor.leaf_span,
    offset: cursor.offset,
  }
}
