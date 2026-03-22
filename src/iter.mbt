///|
/// Walk all elements in the node in order, calling f for each.
fn[T] OrderNode::each(self : OrderNode[T], f : (T) -> Unit) -> Unit {
  match self {
    Leaf(elem~, ..) => f(elem)
    Internal(children~, ..) => children.each(fn(child) { child.each(f) })
  }
}

///|
/// Call f for each element in the tree in order.
pub fn[T] OrderTree::each(self : OrderTree[T], f : (T) -> Unit) -> Unit {
  match self.root {
    None => ()
    Some(node) => node.each(f)
  }
}

///|
/// Collect all elements into an array in order.
pub fn[T] OrderTree::to_array(self : OrderTree[T]) -> Array[T] {
  let result : Array[T] = []
  self.each(fn(elem) { result.push(elem) })
  result
}

///|
/// Return a lazy iterator over elements in order.
/// Materialises the elements into an array first, then returns a pull-based iterator.
pub fn[T] OrderTree::iter(self : OrderTree[T]) -> Iter[T] {
  let arr = self.to_array()
  let mut i = 0
  Iter::new(fn() {
    if i < arr.length() {
      let elem = arr[i]
      i = i + 1
      Some(elem)
    } else {
      None
    }
  })
}
