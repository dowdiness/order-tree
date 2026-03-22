///|
/// Replace the item at the given span position in this node.
/// Span change during set_at is not supported in Phase 1a.
fn[T : @rle.Spanning] OrderNode::set_in_node(
  self : OrderNode[T],
  pos : Int,
  new_item : T,
) -> T? {
  match self {
    Leaf(items~, ..) =>
      items[:].find_by_span(pos, fn(i, _offset) {
        let old = items[i]
        let s = @rle.Spanning::span(old)
        let new_span = @rle.Spanning::span(new_item)
        if new_span != s {
          abort(
            "set_in_node: span change not supported (old=\{s}, new=\{new_span})",
          )
        }
        items[i] = new_item
        Some(old)
      })
    Internal(children~, counts~, ..) =>
      counts[:].find_by_sum(pos, fn(i, remaining) {
        children[i].set_in_node(remaining, new_item)
      })
  }
}

///|
fn[T : @rle.Spanning] OrderNode::navigate(
  self : OrderNode[T],
  pos : Int,
) -> FindResult[T]? {
  match self {
    Leaf(items~, ..) =>
      items[:].find_by_span(pos, fn(i, offset) {
        Some({ item: items[i], offset })
      })
    Internal(children~, counts~, ..) =>
      counts[:].find_by_sum(pos, fn(i, remaining) {
        children[i].navigate(remaining)
      })
  }
}
