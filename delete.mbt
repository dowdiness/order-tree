///|
/// Delete the element at the given span position from the tree.
/// Returns a single-unit slice of the deleted element.
pub fn[T : @btree.BTreeElem] OrderTree::delete_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  let deleted = self.tree.mutate_for_delete(pos, fn(ctx) {
    compute_delete_splice(ctx)
  })
  guard deleted is Some(_) else { return None }
  self.tree.normalize_boundary_at(pos)
  deleted
}
