///|
/// Unwrap a Sliceable::slice result, aborting on failure.
/// Slice failure at a navigated position indicates a violated precondition.
fn[T : @btree.BTreeElem] must_slice(
  elem : T,
  start~ : Int32,
  end~ : Int32,
) -> T {
  match @rle.Sliceable::slice(elem, start~, end~) {
    Ok(result) => result
    Err(_) => abort("OrderTree internal error: slice failed")
  }
}
