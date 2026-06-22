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
  let span = self.tree.span()
  let clamped_pos = if pos < 0 { 0 } else if pos > span { span } else { pos }
  if self.tree.is_empty() {
    self.tree.init_root(elem, elem_span)
  } else {
    self.tree.mutate_for_insert(clamped_pos, fn(ctx) {
      compute_insert_splice(ctx, elem)
    })
  }
}
