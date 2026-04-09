///|
/// Sum all elements of an Int array.
fn Array::sum(self : Array[Int]) -> Int {
  let mut acc = 0
  for x in self {
    acc += x
  }
  acc
}

///|
/// Unwrap a Sliceable::slice result, aborting on failure.
/// Slice failure at a navigated position indicates a violated precondition.
fn[T : @btree.BTreeElem] must_slice(elem : T, start~ : Int, end~ : Int) -> T {
  match @rle.Sliceable::slice(elem, start~, end~) {
    Ok(result) => result
    Err(_) => abort("OrderTree internal error: slice failed")
  }
}
