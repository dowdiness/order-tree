///|
/// Walk all items in the node in order, calling f for each.
fn[T] OrderNode::each(self : OrderNode[T], f : (T) -> Unit) -> Unit {
  match self {
    Leaf(items~, ..) => items.each(f)
    Internal(children~, ..) => children.each(fn(child) { child.each(f) })
  }
}

///|
/// Call f for each item in the tree in order.
pub fn[T] OrderTree::each(self : OrderTree[T], f : (T) -> Unit) -> Unit {
  match self.root {
    None => ()
    Some(node) => node.each(f)
  }
}

///|
/// Collect all items into an array in order.
pub fn[T] OrderTree::to_array(self : OrderTree[T]) -> Array[T] {
  let result : Array[T] = []
  self.each(fn(item) { result.push(item) })
  result
}

///|
/// Return a lazy iterator over items in order.
/// Materialises the items into an array first, then returns a pull-based iterator.
pub fn[T] OrderTree::iter(self : OrderTree[T]) -> Iter[T] {
  let arr = self.to_array()
  let mut i = 0
  Iter::new(fn() {
    if i < arr.length() {
      let item = arr[i]
      i = i + 1
      Some(item)
    } else {
      None
    }
  })
}
