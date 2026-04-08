///|
/// Insert an element at the given position in the tree.
/// Position is clamped to [0, span()]. Element must have span > 0.
pub fn[T : @btree.BTreeElem] OrderTree::insert_at(
  self : OrderTree[T],
  pos : Int,
  elem : T,
) -> Unit {
  let elem_span = @rle.Spanning::span(elem)
  guard elem_span > 0 else { return }
  let clamped_pos = if pos < 0 {
    0
  } else if pos > self.span() {
    self.span()
  } else {
    pos
  }
  match self.root {
    None => {
      let leaf = Leaf(elem~, span=elem_span)
      self.root = Some(
        Internal(children=[leaf], counts=[elem_span], total=elem_span),
      )
      self.size = 1
    }
    Some(root) =>
      match
        descend(
          root,
          clamped_pos,
          self.min_degree,
          prepare_split,
          find_slot_inclusive,
          true,
        ) {
        None => abort("OrderTree::insert_at: descent failed at valid position")
        Some(cursor) => {
          let leaf_ctx = LeafContext::from_cursor(cursor)
          let leaf_result = compute_insert_splice(leaf_ctx, elem)
          let propagated = propagate(
            cursor.path,
            leaf_result.splice,
            self.min_degree,
            leaf_result.leaf_delta,
          )
          match propagated.overflow {
            None => self.root = Some(propagated.node)
            Some(sibling) => {
              let left_total = propagated.node.total()
              let right_total = sibling.total()
              self.root = Some(
                Internal(
                  children=[propagated.node, sibling],
                  counts=[left_total, right_total],
                  total=left_total + right_total,
                ),
              )
            }
          }
          self.size = self.size + propagated.leaf_delta
        }
      }
  }
}
