///|
/// Replace the element at the given span position.
/// Splits the run if needed, tries merge with neighbors.
/// Returns the old single-unit slice, or None if out of bounds.
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderNode::set_in_node(
  self : OrderNode[T],
  pos : Int,
  new_elem : T,
) -> (OrderNode[T], T?) {
  match self {
    Leaf(elem~, span~) => {
      if pos < 0 || pos >= span {
        return (self, None)
      }
      if span == 1 {
        // Direct replacement
        let new_span = @rle.Spanning::span(new_elem)
        (Leaf(elem=new_elem, span=new_span), Some(elem))
      } else {
        // Split: extract single unit at pos, replace with new_elem
        let old_unit = must_slice(elem, start=pos, end=pos + 1)
        let left = if pos > 0 {
          Some(must_slice(elem, start=0, end=pos))
        } else {
          None
        }
        let right = if pos + 1 < span {
          Some(must_slice(elem, start=pos + 1, end=span))
        } else {
          None
        }
        // Try merge left with new_elem, then result with right
        let mut result = new_elem
        let mut result_span = @rle.Spanning::span(new_elem)
        match left {
          Some(l) =>
            if @rle.Mergeable::can_merge(l, result) {
              result = @rle.Mergeable::merge(l, result)
              result_span = @rle.Spanning::span(result)
            } else {
              // Cannot merge left — this case needs parent to handle multi-leaf replacement.
              // For simplicity, rebuild: delete_at + insert_at at tree level.
              // Return None to signal caller should use delete+insert.
              return (self, None)
            }
          None => ()
        }
        match right {
          Some(r) =>
            if @rle.Mergeable::can_merge(result, r) {
              result = @rle.Mergeable::merge(result, r)
              result_span = @rle.Spanning::span(result)
            } else {
              return (self, None)
            }
          None => ()
        }
        (Leaf(elem=result, span=result_span), Some(old_unit))
      }
    }
    Internal(children~, counts~, total~) =>
      match
        counts[:].find_by_sum(pos, fn(i, remaining) { Some((i, remaining)) }) {
        Some((idx, rem)) => {
          let (updated_child, old) = children[idx].set_in_node(rem, new_elem)
          children[idx] = updated_child
          let old_count = counts[idx]
          let new_count = updated_child.total()
          counts[idx] = new_count
          (Internal(children~, counts~, total=total - old_count + new_count), old)
        }
        None => (self, None)
      }
  }
}

///|
/// Navigate to the element containing span position `pos`.
/// Returns FindResult with the element and offset within it.
fn[T] OrderNode::navigate(
  self : OrderNode[T],
  pos : Int,
) -> FindResult[T]? {
  match self {
    Leaf(elem~, span~) =>
      if pos >= 0 && pos < span {
        Some({ elem, offset: pos })
      } else {
        None
      }
    Internal(children~, counts~, ..) =>
      counts[:].find_by_sum(pos, fn(i, remaining) {
        children[i].navigate(remaining)
      })
  }
}
