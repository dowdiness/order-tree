///|
fn[T : @btree.BTreeElem] compute_insert_splice(
  ctx : @btree.LeafContext[T],
  elem : T,
) -> @btree.Splice[T] {
  let elem_span = @rle.Spanning::span(elem)
  if ctx.offset == 0 {
    match ctx.left_neighbor() {
      Some(left_elem) =>
        if @rle.Mergeable::can_merge(left_elem, elem) {
          let merged_left = @rle.Mergeable::merge(left_elem, elem)
          let merged_left_span = @rle.Spanning::span(merged_left)
          let new_leaves : Array[(T, Int)] = [(merged_left, merged_left_span)]
          if @rle.Mergeable::can_merge(merged_left, ctx.elem) {
            let merged = @rle.Mergeable::merge(merged_left, ctx.elem)
            return {
              start_idx: ctx.child_idx - 1,
              end_idx: ctx.child_idx + 1,
              new_leaves: [(merged, @rle.Spanning::span(merged))],
            }
          } else {
            new_leaves.push((ctx.elem, ctx.span))
            return {
              start_idx: ctx.child_idx - 1,
              end_idx: ctx.child_idx + 1,
              new_leaves,
            }
          }
        }
      None => ()
    }
    if @rle.Mergeable::can_merge(elem, ctx.elem) {
      let merged = @rle.Mergeable::merge(elem, ctx.elem)
      return {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [(merged, @rle.Spanning::span(merged))],
      }
    }
    return {
      start_idx: ctx.child_idx,
      end_idx: ctx.child_idx,
      new_leaves: [(elem, elem_span)],
    }
  }
  if ctx.offset == ctx.span {
    if @rle.Mergeable::can_merge(ctx.elem, elem) {
      let merged_current = @rle.Mergeable::merge(ctx.elem, elem)
      match ctx.right_neighbor() {
        Some(right_elem) =>
          if @rle.Mergeable::can_merge(merged_current, right_elem) {
            let merged = @rle.Mergeable::merge(merged_current, right_elem)
            return {
              start_idx: ctx.child_idx,
              end_idx: ctx.child_idx + 2,
              new_leaves: [(merged, @rle.Spanning::span(merged))],
            }
          }
        None => ()
      }
      return {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [(merged_current, @rle.Spanning::span(merged_current))],
      }
    }
    match ctx.right_neighbor() {
      Some(right_elem) =>
        if @rle.Mergeable::can_merge(elem, right_elem) {
          let merged = @rle.Mergeable::merge(elem, right_elem)
          return {
            start_idx: ctx.child_idx + 1,
            end_idx: ctx.child_idx + 2,
            new_leaves: [(merged, @rle.Spanning::span(merged))],
          }
        }
      None => ()
    }
    return {
      start_idx: ctx.child_idx + 1,
      end_idx: ctx.child_idx + 1,
      new_leaves: [(elem, elem_span)],
    }
  }

  let left_part = must_slice(ctx.elem, start=0, end=ctx.offset)
  let right_part = must_slice(ctx.elem, start=ctx.offset, end=ctx.span)
  let right_span = @rle.Spanning::span(right_part)
  let new_leaves : Array[(T, Int)] = []
  let mut current = left_part
  let mut current_span = @rle.Spanning::span(current)
  if @rle.Mergeable::can_merge(current, elem) {
    current = @rle.Mergeable::merge(current, elem)
    current_span = @rle.Spanning::span(current)
  } else {
    new_leaves.push((current, current_span))
    current = elem
    current_span = elem_span
  }
  if @rle.Mergeable::can_merge(current, right_part) {
    current = @rle.Mergeable::merge(current, right_part)
    current_span = @rle.Spanning::span(current)
    new_leaves.push((current, current_span))
  } else {
    new_leaves.push((current, current_span))
    new_leaves.push((right_part, right_span))
  }
  { start_idx: ctx.child_idx, end_idx: ctx.child_idx + 1, new_leaves }
}
