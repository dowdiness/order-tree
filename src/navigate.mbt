///|
/// Navigate to the element containing span position `pos`.
/// Returns FindResult with the element and offset within it.
fn[T] OrderNode::navigate(self : OrderNode[T], pos : Int) -> FindResult[T]? {
  match self {
    Leaf(elem~, span~) =>
      if pos >= 0 && pos < span {
        Some({ elem, offset: pos })
      } else {
        None
      }
    Internal(children~, counts~, ..) =>
      counts[:].find_by_sum(pos, fn(i, remaining) {
        children[i].navigate(remaining)
      })
  }
}
