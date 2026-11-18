///|
/// Abort when the typed Sliceable::slice call fails.
/// Slice failure at a navigated position indicates a violated precondition.
fn[T : @btree.BTreeElem] must_slice(
  elem : T,
  start~ : Int32,
  end~ : Int32,
) -> T {
  @rle.Sliceable::slice(elem, start~, end~) catch {
    _ => abort("OrderTree internal error: slice failed")
  }
}
