///|
/// Replace the item at the given span position in this node.
/// Returns the old item, or None if position is out of bounds.
/// Since span() == 1 for all items in Phase 1a, no span propagation is needed.
fn[T : @rle.Spanning] OrderNode::set_in_node(
  self : OrderNode[T],
  pos : Int,
  new_item : T,
) -> T? {
  match self {
    Leaf(items~, ..) => {
      let mut remaining = pos
      for i = 0; i < items.length(); i = i + 1 {
        let s = @rle.Spanning::span(items[i])
        if remaining < s {
          let old = items[i]
          items[i] = new_item
          return Some(old)
        }
        remaining = remaining - s
      }
      None
    }
    Internal(children~, counts~, ..) => {
      let mut remaining = pos
      for i = 0; i < children.length(); i = i + 1 {
        if remaining < counts[i] {
          return children[i].set_in_node(remaining, new_item)
        }
        remaining = remaining - counts[i]
      }
      None
    }
  }
}

///|
fn[T : @rle.Spanning] OrderNode::navigate(
  self : OrderNode[T],
  pos : Int,
) -> FindResult[T]? {
  match self {
    Leaf(items~, ..) => {
      let mut remaining = pos
      for i = 0; i < items.length(); i = i + 1 {
        let s = @rle.Spanning::span(items[i])
        if remaining < s {
          return Some({ item: items[i], offset: remaining })
        }
        remaining = remaining - s
      }
      None
    }
    Internal(children~, counts~, ..) => {
      let mut remaining = pos
      for i = 0; i < children.length(); i = i + 1 {
        if remaining < counts[i] {
          return children[i].navigate(remaining)
        }
        remaining = remaining - counts[i]
      }
      None
    }
  }
}
