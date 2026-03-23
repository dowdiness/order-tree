# In-Place Multi-Leaf Zipper `delete_range` Plan

## Current Status

Partially implemented as of 2026-03-24.

Implemented:
- boundary descent helpers
- lowest-common-ancestor range planning
- boundary subtree rebuilding
- `NodeSplice` planning
- subtree-splice propagation
- guarded public `delete_range` integration

Current public behavior in `src/order_tree.mbt`:
- use the in-place subtree splice path when occupancy is safe and the retained
  prefix/suffix do not require merge normalization
- fall back to kept-slice rebuild when merge normalization is needed
- fall back to kept-slice rebuild when the planned non-root splice target would
  underflow

So this document is now a follow-up roadmap, not a greenfield implementation
plan.

## Goal

Replace the current rebuild-based `delete_range` with a true in-place multi-leaf zipper algorithm:

1. descend to two boundaries
2. find the lowest common ancestor
3. compute one declarative range splice
4. propagate once

This keeps the walker architecture coherent and avoids repeated local edits or whole-tree rebuilds for range deletion.

## Residual Risks

- Merge normalization remains conservative.
  The planner can absorb some local gap merges, but the public path still
  rebuilds whenever the retained prefix and suffix are mergeable because the
  current in-place logic does not prove full canonicalization for all valid
  `Mergeable` implementations.

- Delete-side underflow repair is still incomplete for arbitrary subtree splices.
  The current in-place public path only runs when the target non-root splice
  point stays above the minimum child-count bound. Cases that would underflow
  still rebuild.

- The range planner in `src/walker_range_delete.mbt` is ahead of the public API.
  Some planning helpers exist as verified infrastructure for future work, but
  the public `delete_range` intentionally uses only the subset that is known to
  preserve current semantics.

## Future TODOs

- Remove the merge-normalization fallback in `OrderTree::delete_range`.
  Implement a proven in-place canonicalization pass for the retained boundary
  region so `delete_range` can preserve fully normalized `Mergeable` behavior
  without rebuilding from kept slices.

- Remove the non-root underflow fallback in `OrderTree::delete_range`.
  Extend subtree-splice propagation with true delete-side occupancy repair
  (borrow/merge after range splice) so arbitrary in-place range deletes can
  maintain B-tree invariants without falling back to rebuild.

## Current Baseline

The current codebase already has:

- single-leaf walker descent in `src/walker_descend.mbt`
- pure leaf splice logic for single-leaf insert/delete
- shared upward rebuild/split logic in `src/walker_propagate.mbt`
- cursor-stepping helpers for ordered leaf traversal
- rebuild-based `delete_range` in `src/order_tree.mbt`

The next step is to add a range planner that targets one ancestor interval instead of one focused leaf.

Important design choice:

- the splice point is the lowest common ancestor (LCA)
- the splice payload must therefore be replacement children at the LCA child height
- the payload cannot be raw `new_leaves`, because the LCA may sit above the leaf parent

## File Plan

Keep the current split and add only the missing range-specific layers.

- `src/walker_types.mbt`
  - extend with range-specific structs

- `src/walker_descend.mbt`
  - keep point descent
  - add boundary-descent helpers

- `src/walker_propagate.mbt`
  - keep current propagate logic
  - add entrypoint for applying a splice at an arbitrary ancestor prefix

- `src/walker_range.mbt`
  - new
  - lowest-common-ancestor logic
  - ancestor interval extraction
  - boundary normalization helpers

- `src/walker_range_delete.mbt`
  - new
  - one-shot multi-leaf delete-range planner

- `src/order_tree.mbt`
  - switch `delete_range` from rebuild-based kept slices to one planned subtree splice

- `src/walker_wbtest.mbt`
  - add white-box tests for LCA and range planning

- `src/order_tree_test.mbt`
  - keep black-box range-delete behavior tests

## Data Structures

Minimize churn by keeping the current single-leaf cursor and adding range-specific wrappers first.

```moonbit
priv struct LeafCursor[T] {
  path : Array[PathFrame[T]]
  elem : T
  span : Int
  offset : Int
}
```

```moonbit
priv struct AncestorRange[T] {
  prefix : Array[PathFrame[T]]
  children : Array[OrderNode[T]]
  counts : Array[Int]
  start_idx : Int
  end_idx : Int
  child_height : Int
}
```

```moonbit
priv struct NodeSplice[T] {
  prefix : Array[PathFrame[T]]
  start_idx : Int
  end_idx : Int
  new_children : Array[OrderNode[T]]
  leaf_delta : Int
}
```

```moonbit
priv struct BoundarySubtrees[T] {
  left : OrderNode[T]?
  right : OrderNode[T]?
}
```

These should live in `src/walker_types.mbt`.

## Phase 1: Boundary Descent

Add helpers to `src/walker_descend.mbt`:

```moonbit
fn[T] cursor_as_leaf(cursor : Cursor[T]) -> LeafCursor[T]?
```

```moonbit
fn[T] descend_leaf_at(
  node : OrderNode[T],
  pos : Int,
  min_degree : Int,
) -> LeafCursor[T]?
```

```moonbit
fn[T] descend_leaf_at_end_boundary(
  node : OrderNode[T],
  end_ : Int,
  min_degree : Int,
) -> LeafCursor[T]?
```

Semantics:

- `descend_leaf_at(start)` returns the leaf containing the first removed unit
- `descend_leaf_at_end_boundary(end_)` returns the leaf touching the exclusive right boundary

The current `descend`, `cursor_next_leaf`, and `each_slice_in_range` remain useful and should stay.

## Phase 2: Lowest Common Ancestor

Create `src/walker_range.mbt`.

Add:

```moonbit
fn[T] shared_prefix_length(
  left : Array[PathFrame[T]],
  right : Array[PathFrame[T]],
) -> Int
```

```moonbit
fn[T] lowest_common_ancestor_range(
  start : LeafCursor[T],
  end_ : LeafCursor[T],
) -> AncestorRange[T]
```

Behavior:

- compare both paths until child indices diverge
- shared path before divergence becomes `prefix`
- target ancestor owns the child interval `[start_idx, end_idx)`

Important:

- `end_idx` stays exclusive
- handle the same-parent and same-leaf cases explicitly

## Phase 3: Boundary Subtree Planning

Still in `src/walker_range.mbt`, add:

```moonbit
fn[T] OrderNode::height(self : OrderNode[T]) -> Int
```

```moonbit
fn[T] build_single_chain(
  path_suffix : Array[PathFrame[T]],
  leaf : OrderNode[T],
) -> OrderNode[T]
```

Rules:

- `height` is used for validation and testing
- `build_single_chain` rebuilds one boundary path from a leaf replacement up to the LCA child height

Then add the boundary subtree helpers in `src/walker_range_delete.mbt`:

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] left_boundary_subtree(
  lca : AncestorRange[T],
  start : LeafCursor[T],
) -> OrderNode[T]?
```

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] right_boundary_subtree(
  lca : AncestorRange[T],
  end_ : LeafCursor[T],
) -> OrderNode[T]?
```

Rules:

- if the boundary keeps nothing, return `None`
- otherwise slice the boundary leaf and rebuild the path from that leaf up to one child directly under the LCA
- the returned node must have the same height as every other child in `lca.children`

Special case:

- if `start` and `end_` fall within the same LCA child, plan that side as one rebuilt subtree, not two independent boundary subtrees

## Phase 4: Range Delete Planner

Create `src/walker_range_delete.mbt`.

Main entrypoint:

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] plan_delete_range(
  root : OrderNode[T],
  start : Int,
  end_ : Int,
  min_degree : Int,
) -> NodeSplice[T]?
```

Algorithm:

1. guard empty and out-of-range cases
2. descend to `start`
3. descend to right boundary `end_`
4. compute lowest common ancestor interval
5. compute left/right boundary subtrees at the LCA child height
6. preserve any untouched middle children that remain valid at that same height
7. build `new_children`
8. compute `leaf_delta`
9. return one `NodeSplice`

Special case:

If `[start, end_)` falls within one leaf, reduce to a generalized single-leaf range edit, then rebuild that one edited leaf back to the LCA child height.

Add helper:

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] compute_single_leaf_delete_range(
  leaf : LeafCursor[T],
  start_offset : Int,
  end_offset : Int,
) -> Array[(T, Int)]
```

This helper remains leaf-local. Its result must still be lifted into subtree form before the final LCA splice.

## Phase 5: Propagate From Arbitrary Ancestor

Extend `src/walker_propagate.mbt`.

Current `propagate` assumes the splice is applied in the parent of a focused leaf.

Add:

```moonbit
fn[T] apply_node_splice(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  start_idx : Int,
  end_idx : Int,
  new_children : Array[OrderNode[T]],
) -> Unit
```

```moonbit
fn[T] propagate_node_splice(
  splice : NodeSplice[T],
  min_degree : Int,
) -> PropagateResult[T]
```

Behavior:

- apply the splice directly to the ancestor arrays referenced by the range
- replacement children must already match the LCA child height
- split if needed there
- propagate once through `splice.prefix`

This should reuse as much of the existing `maybe_split` and upward propagation logic as possible.

Important:

- this is a general subtree splice, not a leaf splice
- `apply_splice` for leaf splices and `apply_node_splice` for subtree splices should coexist unless the code is fully unified
- delete-side occupancy repair is still a separate concern; split-only upward propagation is not sufficient if the splice can leave an internal node below `min_degree`

## Phase 6: Switch `delete_range`

Update `src/order_tree.mbt`.

Replace the current rebuild-based implementation with:

1. clamp `[start, end_)`
2. call `plan_delete_range`
3. call `propagate_node_splice`
4. normalize root if needed
5. update `size`

Update the docstring to describe the new implementation as:

- in-place multi-leaf zipper delete
- one planned subtree splice at the LCA
- one propagation pass

## Phase 7: Tests

### White-box tests in `src/walker_wbtest.mbt`

Add tests for:

- shared prefix / LCA interval computation
- left and right boundary subtree rebuilding
- same-leaf range delete planning
- multi-leaf range delete planning
- propagation from an ancestor above the leaf parent

### Black-box tests in `src/order_tree_test.mbt`

Keep and extend tests for:

- full-span delete
- exact-boundary delete
- negative / oversized inputs
- cross-leaf delete
- merge-across-gap delete
- same-leaf partial delete

## Phase 8: Benchmarks

Only after correctness is stable:

- compare the current rebuild-based `delete_range`
- compare the new in-place multi-leaf zipper `delete_range`

Use `src/order_tree_benchmark.mbt` and update `BENCHMARK_RESULTS.md` if the algorithm changes.

## Recommended Commit Sequence

1. add range structs and boundary-descent helpers
2. add LCA/range planner plus white-box tests
3. switch `delete_range` to in-place subtree splice plus black-box tests
4. rerun benchmarks and record results

## Main Risks

- off-by-one at exclusive `end_`
- incorrect ancestor interval when both boundaries share a parent
- invalid replacement child height at the LCA splice point
- wrong `leaf_delta`
- root normalization mistakes after large deletes
- incorrect reconstruction of boundary subtrees

## Guiding Rule

Do not implement this as repeated cursor stepping with incremental mutation.

The correct zipper shape here is:

- navigate with cursors
- plan one declarative subtree splice at the LCA
- propagate once

That preserves the architecture established by the current walker refactor.
