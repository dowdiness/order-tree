///|
/// Remove an element at the given index from an array, returning the removed element.
/// Shifts subsequent elements left.
fn[T] array_remove(arr : Array[T], idx : Int) -> T {
  let item = arr[idx]
  for i = idx; i < arr.length() - 1; i = i + 1 {
    arr[i] = arr[i + 1]
  }
  let _ = arr.pop()
  item
}

///|
/// Insert an element at the given index in an array.
/// Shifts subsequent elements right.
fn[T] array_insert(arr : Array[T], idx : Int, item : T) -> Unit {
  arr.push(item) // extend length by 1
  for i = arr.length() - 1; i > idx; i = i - 1 {
    arr[i] = arr[i - 1]
  }
  arr[idx] = item
}

///|
/// Compute the total span of an array of items.
fn[T : @rle.Spanning] compute_items_span(items : Array[T]) -> Int {
  let mut total = 0
  for i = 0; i < items.length(); i = i + 1 {
    total = total + @rle.Spanning::span(items[i])
  }
  total
}

///|
/// Sum all elements of an Int array.
fn sum_array(arr : Array[Int]) -> Int {
  let mut total = 0
  for i = 0; i < arr.length(); i = i + 1 {
    total = total + arr[i]
  }
  total
}

///|
/// Get the total span of a node.
fn[T] node_total(node : OrderNode[T]) -> Int {
  match node {
    Leaf(total~, ..) => total
    Internal(total~, ..) => total
  }
}

///|
/// Check if a node is full.
/// Leaves: max items = 2*t - 1.
/// Internal: max children = 2*t.
fn[T] is_node_full(node : OrderNode[T], min_degree : Int) -> Bool {
  let max_items = 2 * min_degree - 1
  match node {
    Leaf(items~, ..) => items.length() >= max_items
    Internal(children~, ..) => children.length() >= 2 * min_degree
  }
}
