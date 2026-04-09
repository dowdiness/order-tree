///|
fn[T : @btree.BTreeElem] compute_delete_splice(
  ctx : @btree.LeafContext[T],
) -> (@btree.Splice[T], T) {
  if ctx.span == 1 {
    match (ctx.left_neighbor(), ctx.right_neighbor()) {
      (Some(left_elem), Some(right_elem)) =>
        if @rle.Mergeable::can_merge(left_elem, right_elem) {
          let merged = @rle.Mergeable::merge(left_elem, right_elem)
          return (
            {
              start_idx: ctx.child_idx - 1,
              end_idx: ctx.child_idx + 2,
              new_leaves: [(merged, @rle.Spanning::span(merged))],
            },
            ctx.elem,
          )
        }
      _ => ()
    }
    return (
      {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [],
      },
      ctx.elem,
    )
  }
  if ctx.offset == 0 {
    let deleted = must_slice(ctx.elem, start=0, end=1)
    let rest = must_slice(ctx.elem, start=1, end=ctx.span)
    match ctx.left_neighbor() {
      Some(left_elem) =>
        if @rle.Mergeable::can_merge(left_elem, rest) {
          let merged = @rle.Mergeable::merge(left_elem, rest)
          return (
            {
              start_idx: ctx.child_idx - 1,
              end_idx: ctx.child_idx + 1,
              new_leaves: [(merged, @rle.Spanning::span(merged))],
            },
            deleted,
          )
        }
      None => ()
    }
    return (
      {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [(rest, @rle.Spanning::span(rest))],
      },
      deleted,
    )
  }
  if ctx.offset == ctx.span - 1 {
    let deleted = must_slice(ctx.elem, start=ctx.span - 1, end=ctx.span)
    let rest = must_slice(ctx.elem, start=0, end=ctx.span - 1)
    match ctx.right_neighbor() {
      Some(right_elem) =>
        if @rle.Mergeable::can_merge(rest, right_elem) {
          let merged = @rle.Mergeable::merge(rest, right_elem)
          return (
            {
              start_idx: ctx.child_idx,
              end_idx: ctx.child_idx + 2,
              new_leaves: [(merged, @rle.Spanning::span(merged))],
            },
            deleted,
          )
        }
      None => ()
    }
    return (
      {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [(rest, @rle.Spanning::span(rest))],
      },
      deleted,
    )
  }

  let deleted = must_slice(ctx.elem, start=ctx.offset, end=ctx.offset + 1)
  let left_part = must_slice(ctx.elem, start=0, end=ctx.offset)
  let right_part = must_slice(ctx.elem, start=ctx.offset + 1, end=ctx.span)
  if @rle.Mergeable::can_merge(left_part, right_part) {
    let merged = @rle.Mergeable::merge(left_part, right_part)
    return (
      {
        start_idx: ctx.child_idx,
        end_idx: ctx.child_idx + 1,
        new_leaves: [(merged, @rle.Spanning::span(merged))],
      },
      deleted,
    )
  }
  (
    {
      start_idx: ctx.child_idx,
      end_idx: ctx.child_idx + 1,
      new_leaves: [
        (left_part, @rle.Spanning::span(left_part)),
        (right_part, @rle.Spanning::span(right_part)),
      ],
    },
    deleted,
  )
}
