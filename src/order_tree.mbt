///|
pub fn[T] OrderTree::new(
  min_degree? : Int = default_min_degree,
) -> OrderTree[T] {
  let min_degree = if min_degree < 2 { 2 } else { min_degree }
  { root: None, min_degree, size: 0 }
}

///|
pub fn[T] OrderTree::is_empty(self : OrderTree[T]) -> Bool {
  self.root is None
}

///|
pub fn[T] OrderTree::span(self : OrderTree[T]) -> Int {
  match self.root {
    None => 0
    Some(Leaf(total~, ..)) => total
    Some(Internal(total~, ..)) => total
  }
}

///|
pub fn[T] OrderTree::size(self : OrderTree[T]) -> Int {
  self.size
}

///|
pub fn[T : @rle.Spanning] OrderTree::get_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  match self.root {
    None => None
    Some(node) =>
      match node.navigate(pos) {
        Some(result) => Some(result.item)
        None => None
      }
  }
}

///|
pub fn[T : @rle.Spanning] OrderTree::find(
  self : OrderTree[T],
  pos : Int,
) -> FindResult[T]? {
  match self.root {
    None => None
    Some(node) => node.navigate(pos)
  }
}

///|
/// Replace the item at the given span position.
/// Returns the old item, or None if the position is out of bounds.
pub fn[T : @rle.Spanning] OrderTree::set_at(
  self : OrderTree[T],
  pos : Int,
  item : T,
) -> T? {
  match self.root {
    None => None
    Some(node) => node.set_in_node(pos, item)
  }
}

///|
/// Delete all items in the span range [start, end).
/// Uses repeated delete_at(start) calls. O(k log n) where k = end - start.
pub fn[T : @rle.Spanning] OrderTree::delete_range(
  self : OrderTree[T],
  start : Int,
  end_ : Int,
) -> Unit {
  let count = end_ - start
  for i = 0; i < count; i = i + 1 {
    ignore(self.delete_at(start))
  }
}
