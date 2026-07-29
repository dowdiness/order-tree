///|
/// Test helper type for invariant tests
priv struct TI {
  value : Int
  item_span : Int
}

///|
impl @rle.HasLength for TI with fn length(_self) -> Int {
  1
}

///|
impl @rle.Spanning for TI with fn span(self) -> Int {
  self.item_span
}

///|
impl @rle.Mergeable for TI with fn can_merge(_self, _other) -> Bool {
  false
}

///|
impl @rle.Mergeable for TI with fn merge(_self, _other) -> TI {
  abort("TI::merge: unreachable — can_merge always returns false")
}

///|
impl @rle.Sliceable for TI with fn slice(self, start~ : Int, end~ : Int) -> Result[
  TI,
  @rle.RleError,
] {
  if start == 0 && end == 1 {
    Ok(self)
  } else {
    Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
}

///|
impl @btree.BTreeElem for TI

///|
fn mki(v : Int) -> TI {
  { value: v, item_span: 1 }
}

///|
/// Check OrderTree-owned invariants through its public API.
fn[T : @btree.BTreeElem] check_invariants(tree : OrderTree[T]) -> String? {
  let items = tree.to_array()
  if tree.size() != items.length() {
    return Some(
      "size mismatch: tree.size=\{tree.size()} actual=\{items.length()}",
    )
  }
  let spans = items.map(item => @rle.Spanning::span(item))
  if !spans.all(span => span > 0) {
    return Some("to_array contains a non-positive span")
  }
  let expected_span = spans.iter().fold(init=0, (total, span) => total + span)
  if tree.span() != expected_span {
    return Some(
      "span mismatch: tree.span=\{tree.span()} actual=\{expected_span}",
    )
  }
  for i in 0..<(items.length() - 1) {
    if @rle.Mergeable::can_merge(items[i], items[i + 1]) {
      return Some("to_array contains adjacent mergeable elements")
    }
  }
  for item in items; pos = 0 {
    let expected_item_span = @rle.Spanning::span(item)
    match tree.find(pos) {
      Some(found) =>
        if found.offset != 0 ||
          @rle.Spanning::span(found.elem) != expected_item_span {
          return Some("find disagrees with to_array at position \{pos}")
        }
      None => return Some("find returned None at position \{pos}")
    }
    continue pos + expected_item_span
  }
  None
}

///|
test "invariants hold after sequential inserts" {
  @qc.quick_check_fn(fn(count : Int) -> Bool {
    let r = count % 50
    let count = if r < 0 { -r } else { r }
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    for i = 0; i < count; i = i + 1 {
      tree.insert_at(i, mki(i))
      match check_invariants(tree) {
        Some(_) => return false
        None => ()
      }
    }
    true
  })
}

///|
test "invariants hold after sequential deletes" {
  @qc.quick_check_fn(fn(count : Int) -> Bool {
    let r = count % 50
    let count = if r < 0 { -r } else { r }
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    for i = 0; i < count; i = i + 1 {
      tree.insert_at(i, mki(i))
    }
    for i = 0; i < count; i = i + 1 {
      ignore(tree.delete_at(0))
      match check_invariants(tree) {
        Some(_) => return false
        None => ()
      }
    }
    true
  })
}

///|
test "invariants hold after from_array" {
  @qc.quick_check_fn(fn(n : Int) -> Bool {
    let r = n % 50
    let n = if r < 0 { -r } else { r }
    let tree = OrderTree::from_array(
      Array::makei(n, fn(i) { mki(i) }),
      min_degree=2,
    )
    match check_invariants(tree) {
      Some(_) => false
      None => true
    }
  })
}

///|
test "invariants hold after mixed insert and delete" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  // Insert 30
  for i = 0; i < 30; i = i + 1 {
    tree.insert_at(i, mki(i))
  }
  // Delete 15 from various positions
  for i = 0; i < 15; i = i + 1 {
    ignore(tree.delete_at(i % tree.span()))
    match check_invariants(tree) {
      Some(e) => fail("after mixed delete \{i}: \{e}")
      None => ()
    }
  }
  // Insert 10 more
  for i = 0; i < 10; i = i + 1 {
    tree.insert_at(i % (tree.span() + 1), mki(100 + i))
    match check_invariants(tree) {
      Some(e) => fail("after mixed insert \{i}: \{e}")
      None => ()
    }
  }
}
