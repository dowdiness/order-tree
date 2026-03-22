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
