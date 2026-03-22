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
      find_in_leaf(items[:], pos, fn(i, _offset) {
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
      find_child(counts[:], pos, fn(i, remaining) {
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
      find_in_leaf(items[:], pos, fn(i, offset) {
        Some({ item: items[i], offset })
      })
    Internal(children~, counts~, ..) =>
      find_child(counts[:], pos, fn(i, remaining) {
        children[i].navigate(remaining)
      })
  }
}

///|
/// Walk leaf items by span to find the item at position `pos`.
/// Pattern-matches on ArrayView to destructure head + tail.
fn[T : @rle.Spanning, R] find_in_leaf(
  items : ArrayView[T],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  loop (items, pos, 0) {
    ([], _, _) => None
    ([item, .. rest], remaining, i) => {
      let s = @rle.Spanning::span(item)
      if remaining < s {
        f(i, remaining)
      } else {
        continue (rest, remaining - s, i + 1)
      }
    }
  }
}

///|
/// Walk internal node counts to find which child contains position `pos`.
/// Pattern-matches on ArrayView for clean destructuring.
fn[R] find_child(
  counts : ArrayView[Int],
  pos : Int,
  f : (Int, Int) -> R?,
) -> R? {
  loop (counts, pos, 0) {
    ([], _, _) => None
    ([count, ..], remaining, i) if remaining < count => f(i, remaining)
    ([count, .. rest], remaining, i) =>
      continue (rest, remaining - count, i + 1)
  }
}
