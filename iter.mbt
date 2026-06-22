///|
/// Call f for each element in the tree in order.
pub fn[T] OrderTree::each(self : OrderTree[T], f : (T) -> Unit) -> Unit {
  self.tree.each(f)
}

///|
/// Collect all elements into an array in order.
pub fn[T] OrderTree::to_array(self : OrderTree[T]) -> Array[T] {
  self.tree.to_array()
}

///|
/// Return a lazy iterator over elements in order.
pub fn[T] OrderTree::iter(self : OrderTree[T]) -> Iter[T] {
  self.tree.iter()
}
