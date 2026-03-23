///|
fn[T] normalize_root_after_delete(root : OrderNode[T]) -> OrderNode[T]? {
  match root {
    Internal(children~, ..) =>
      if children.length() == 0 {
        None
      } else if children.length() == 1 {
        match children[0] {
          Internal(..) => Some(children[0])
          Leaf(..) => Some(root)
        }
      } else {
        Some(root)
      }
    Leaf(..) => abort("normalize_root_after_delete: root should be internal")
  }
}

///|
/// Delete the element at the given span position from the tree.
/// Returns a single-unit slice of the deleted element.
pub fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderTree::delete_at(
  self : OrderTree[T],
  pos : Int,
) -> T? {
  match self.root {
    None => None
    Some(root) => {
      if pos < 0 || pos >= root.total() {
        return None
      }
      match descend(
        root,
        pos,
        self.min_degree,
        prepare_ensure_min,
        find_slot,
        false,
      ) {
        None => None
        Some(cursor) => {
          let leaf_ctx = LeafContext::from_cursor(cursor)
          let leaf_result = compute_delete_splice(leaf_ctx)
          let propagated = propagate(
            cursor.path,
            leaf_result.splice,
            self.min_degree,
            leaf_result.leaf_delta,
          )
          self.root = normalize_root_after_delete(propagated.node)
          self.size = self.size + propagated.leaf_delta
          Some(leaf_result.deleted)
        }
      }
    }
  }
}
