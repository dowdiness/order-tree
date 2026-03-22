///|
pub fn[T] OrderTree::new(
  min_degree? : Int = default_min_degree,
) -> OrderTree[T] {
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
