///|
/// Navigate to the element containing span position `pos`.
/// Returns FindResult with the element and offset within it.
fn[T] OrderNode::navigate(self : OrderNode[T], pos : Int) -> FindResult[T]? {
  match descend(self, pos, 0, prepare_noop, find_slot, false) {
    Some(cursor) => Some({ elem: cursor.leaf_elem, offset: cursor.offset })
    None => None
  }
}
