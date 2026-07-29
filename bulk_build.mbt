///|
/// Build an OrderTree from an array of elements in O(n) time.
/// Filters zero-span items, pre-merges adjacent mergeable elements,
/// then builds bottom-up.
pub fn[T : @rle.Spanning + @rle.Mergeable] OrderTree::from_array(
  items : Array[T],
  min_degree? : Int,
) -> OrderTree[T] {
  let t = match min_degree {
    Some(d) => if d < 2 { 2 } else { d }
    None => 10
  }
  if items.is_empty() {
    return OrderTree::new(min_degree=t)
  }
  // Filter zero-span and pre-merge adjacent elements
  let merged : Array[T] = []
  for item in items {
    if @rle.Spanning::span(item) <= 0 {
      continue
    }
    match merged.last() {
      Some(last) =>
        if @rle.Mergeable::can_merge(last, item) {
          merged[merged.length() - 1] = @rle.Mergeable::merge(last, item)
        } else {
          merged.push(item)
        }
      None => merged.push(item)
    }
  }
  if merged.is_empty() {
    return OrderTree::new(min_degree=t)
  }
  let pairs = merged.map(elem => (elem, @rle.Spanning::span(elem)))
  { tree: @btree.BTree::from_sorted(pairs, min_degree=t) }
}
