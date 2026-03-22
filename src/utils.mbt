///|
/// Remove an element at the given index, shifting subsequent elements left.
fn[T] Array::remove_at(self : Array[T], idx : Int) -> T {
  let item = self[idx]
  for i = idx; i < self.length() - 1; i = i + 1 {
    self[i] = self[i + 1]
  }
  let _ = self.pop()
  item
}

///|
/// Insert an element at the given index, shifting subsequent elements right.
fn[T] Array::insert_at(self : Array[T], idx : Int, item : T) -> Unit {
  self.push(item)
  for i = self.length() - 1; i > idx; i = i - 1 {
    self[i] = self[i - 1]
  }
  self[idx] = item
}

///|
/// Compute the total span of an array of items.
fn[T : @rle.Spanning] Array::total_span(self : Array[T]) -> Int {
  let mut total = 0
  for i = 0; i < self.length(); i = i + 1 {
    total = total + @rle.Spanning::span(self[i])
  }
  total
}

///|
/// Sum all elements of an Int array.
fn Array::sum(self : Array[Int]) -> Int {
  let mut total = 0
  for i = 0; i < self.length(); i = i + 1 {
    total = total + self[i]
  }
  total
}

///|
/// Get the total span of a node.
fn[T] OrderNode::total(self : OrderNode[T]) -> Int {
  match self {
    Leaf(total~, ..) => total
    Internal(total~, ..) => total
  }
}

///|
/// Check if a node is full.
/// Leaves: max items = 2*t - 1.
/// Internal: max children = 2*t.
fn[T] OrderNode::is_full(self : OrderNode[T], min_degree : Int) -> Bool {
  match self {
    Leaf(items~, ..) => items.length() >= 2 * min_degree - 1
    Internal(children~, ..) => children.length() >= 2 * min_degree
  }
}
