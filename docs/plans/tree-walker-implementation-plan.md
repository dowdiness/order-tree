# Implementation Plan: Tree Walker (Zipper) Infrastructure for order-tree

## Status

This plan is effectively complete as of 2026-03-24.

Implemented:
- walker-based descent, pure leaf actions, and upward propagation
- rewritten `navigate`, `insert_at`, and `delete_at`
- cursor-based `view`
- guarded in-place `delete_range` planning and subtree propagation
- white-box coverage for walker, range, and propagation helpers
- final cleanup with a warning-free `moon check`

Still intentionally conservative:
- `delete_range` falls back to rebuild when retained ranges need canonical merge
  normalization
- `delete_range` also falls back when the planned in-place subtree splice would
  underflow a non-root target node

See `docs/plans/2026-03-24-in-place-multi-leaf-zipper-delete-range-plan.md`
for the remaining range-delete-specific follow-up work.

## Overview

The current `insert.mbt` (300 lines) and `delete.mbt` (340 lines) interleave four concerns:
1. Descent by cumulative span count
2. B-tree invariant maintenance during descent
3. Leaf-level RLE logic (merge/split/slice)
4. Change propagation back to root

This refactoring separates them using a Zipper pattern. After refactoring:
- Navigate: descend + read cursor (~5 lines)
- Insert: descend(prepare=split) + compute_insert_splice + propagate (~80 lines of RLE logic)
- Delete: descend(prepare=ensure_min) + compute_delete_splice + propagate (~80 lines of RLE logic)

All existing tests must pass at every phase.

## File Plan

New files added alongside existing code:

```
order-tree/src/
  types.mbt              — unchanged
  utils.mbt              — unchanged (find_by_sum stays here)
  walker_types.mbt       — NEW: PathFrame, Cursor, LeafContext, Splice
  walker_descend.mbt     — NEW: find_slot, descend
  walker_propagate.mbt   — NEW: apply_splice, try_merge_boundaries, propagate
  walker_insert.mbt      — NEW: compute_insert_splice (pure RLE logic)
  walker_delete.mbt      — NEW: compute_delete_splice (pure RLE logic)
  navigate.mbt           — rewritten using walker
  insert.mbt             — rewritten using walker
  delete.mbt             — rewritten using walker
  walker_test.mbt        — NEW: unit tests for walker components
  ... (existing test files unchanged)
```

---

## Phase 0: Verify Patterns

Before writing real code, confirm these patterns compile in MoonBit:

```moonbit
// 1. Struct with Array fields and Int fields
struct PathFrame[T] {
  children : Array[OrderNode[T]]
  counts : Array[Int]
  total : Int
  child_idx : Int
}

// 2. Function taking a closure that mutates external state
fn test_closure() -> Int {
  let mut acc = 0
  let f = fn(x : Int) { acc = acc + x }
  f(1)
  f(2)
  acc  // should be 3
}

// 3. Array of structs, pushing and indexing
fn test_path() -> Unit {
  let path : Array[PathFrame[Int]] = []
  // ... can we push PathFrame values and index back?
}
```

**Exit criterion:** `moon check` passes on all patterns.

---

## Phase 1: Core Types

**File:** `walker_types.mbt`

### PathFrame

One level of the descent stack. Records the parent's state and which child we descended into.

```moonbit
/// One frame of the descent path from root to the focused leaf.
/// Stores references to the parent Internal node's arrays.
struct PathFrame[T] {
  children : Array[OrderNode[T]]
  counts : Array[Int]
  total : Int
  child_idx : Int
}
```

### Cursor

The result of a successful descent. Points at a leaf with full path context.

```moonbit
/// A cursor pointing at a leaf in the tree.
/// path[0] is the root's frame, path[last] is the leaf's parent.
struct Cursor[T] {
  path : Array[PathFrame[T]]
  leaf_elem : T
  leaf_span : Int
  offset : Int          // position within the leaf (0..span-1)
  child_idx : Int       // index of this leaf within its parent's children
}
```

### LeafContext

What the leaf-action function sees. Provides neighbor access for RLE merge decisions.

```moonbit
/// Context available when deciding what to do at a leaf.
/// Provides read access to neighboring leaves for merge decisions.
struct LeafContext[T] {
  elem : T
  span : Int
  offset : Int
  // Parent's arrays for neighbor access
  children : Array[OrderNode[T]]
  counts : Array[Int]
  child_idx : Int
}
```

With helper methods:

```moonbit
fn[T] LeafContext::left_neighbor(self : LeafContext[T]) -> T?
fn[T] LeafContext::right_neighbor(self : LeafContext[T]) -> T?
fn[T] LeafContext::from_cursor(cursor : Cursor[T]) -> LeafContext[T]
```

`left_neighbor` returns `Some(elem)` if `child_idx > 0` and `children[child_idx - 1]` is a Leaf. Same logic for `right_neighbor`. These are read-only — they never modify the arrays.

### Splice

The declarative result of a leaf action. Describes how to modify the parent's children array.

```moonbit
/// Describes a modification to a range of the parent's children array.
/// Replace children[start_idx .. end_idx) with new_leaves.
///
/// Examples:
///   Insert before:    Splice(idx, idx, [(new, span)])              — insert, no removal
///   Replace in place: Splice(idx, idx+1, [(modified, new_span)])   — 1:1 replacement
///   Delete leaf:      Splice(idx, idx+1, [])                       — remove, no insert
///   Split leaf:       Splice(idx, idx+1, [(left, s1), (right, s2)]) — 1:2 expansion
///   Merge with left:  Splice(idx-1, idx+1, [(merged, s)])          — 2:1 collapse
struct Splice[T] {
  start_idx : Int                // inclusive
  end_idx : Int                  // exclusive
  new_leaves : Array[(T, Int)]   // (elem, span) pairs to insert
}
```

### PropagateResult

What comes out of propagation.

```moonbit
struct PropagateResult[T] {
  node : OrderNode[T]
  overflow : OrderNode[T]?    // Some if this node split
  leaf_delta : Int             // net change in leaf count
  span_delta : Int             // net change in total span
}
```

### Tests

```moonbit
test "LeafContext neighbor access" {
  // Build a small Internal node with 3 leaves
  // Verify left_neighbor / right_neighbor return correct values
  // Verify boundary cases (first child has no left, last has no right)
}
```

**Exit criterion:** Types compile, LeafContext helpers pass tests.

---

## Phase 2: Descent

**File:** `walker_descend.mbt`

### Slot Finding

Extract the cumulative-sum slot search into standalone functions. These replace the inline `find_by_sum` / `find_by_sum_inclusive` usage.

```moonbit
/// Find child index and remaining offset for position pos.
/// Uses strict < comparison (for navigate and delete).
fn find_slot(counts : Array[Int], pos : Int, total : Int) -> (Int, Int)

/// Find child index and remaining offset for position pos.
/// Uses <= comparison (for insert — position at boundary goes to current slot).
fn find_slot_inclusive(counts : Array[Int], pos : Int, total : Int) -> (Int, Int)
```

Implementation: linear scan through counts, accumulating sum. If pos < running_sum, return (i, pos - previous_sum). Fall back to last child.

### Descend

The core descent function. Takes a `prepare` hook that runs at each Internal node before choosing a child.

```moonbit
/// Descend from a node to the leaf at span position `pos`.
///
/// `prepare` is called at each Internal node before descending.
///   - For navigate: no-op
///   - For insert: proactive split of full children
///   - For delete: ensure_min_children
///
/// `find_slot_fn` determines < vs <= boundary behavior:
///   - For navigate/delete: find_slot (strict <)
///   - For insert: find_slot_inclusive (<=)
///
/// Returns None if pos is out of bounds.
fn[T] descend(
  node : OrderNode[T],
  pos : Int,
  min_degree : Int,
  prepare : (Array[OrderNode[T]], Array[Int], Int, Int) -> Unit,
  find_slot_fn : (Array[Int], Int, Int) -> (Int, Int),
) -> Cursor[T]?
```

Implementation:

```
loop with (current_node, current_pos):
  match current_node:
    Leaf(elem, span) →
      if current_pos in bounds: return Some(Cursor { path, elem, span, offset, child_idx })
      else: return None
    Internal(children, counts, total) →
      (preliminary_idx, _) = find_slot_fn(counts, current_pos, total)
      prepare(children, counts, preliminary_idx, min_degree)
      // Re-find after prepare may have changed arrays
      (child_idx, remaining) = find_slot_fn(counts, current_pos, recompute_total(counts))
      path.push(PathFrame { children, counts, total, child_idx })
      continue with (children[child_idx], remaining)
```

**Important:** After `prepare` runs (e.g., proactive split splits a child into two), the counts array may have changed. We must re-find the slot. The total also needs recomputation if prepare modified counts.

### Prepare Hooks

These are the existing functions, extracted as standalone:

```moonbit
/// Proactive split: if children[idx] is a full Internal, split it.
/// Used by insert's descent.
fn[T] prepare_split(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
  min_degree : Int,
) -> Unit

/// Ensure min children: if children[idx] has too few children, rebalance.
/// Used by delete's descent.
fn[T] prepare_ensure_min(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  idx : Int,
  min_degree : Int,
) -> Unit
```

These are essentially the existing `proactive_split` logic (lines 253-273 in insert.mbt) and `ensure_min_children` (lines 128-150 in delete.mbt) extracted as functions.

### Tests

```moonbit
test "find_slot basic" {
  // counts = [3, 5, 2], total = 10
  // pos 0 → (0, 0), pos 2 → (0, 2), pos 3 → (1, 0), pos 7 → (1, 4), pos 8 → (2, 0)
}

test "find_slot_inclusive boundary" {
  // counts = [3, 5, 2], total = 10
  // pos 3 → (0, 3) with inclusive (goes to current slot at boundary)
  // pos 3 → (1, 0) with strict (goes to next slot)
}

test "descend navigate simple" {
  // Build a 2-level tree, descend to various positions
  // Verify cursor.leaf_elem, cursor.offset, cursor.path.length()
}

test "descend with prepare_split" {
  // Build a tree with a full child, descend with prepare_split
  // Verify the full child was split and descent still reaches correct leaf
}
```

**Exit criterion:** All descent tests pass. Existing order-tree tests still pass (descent is new code, not yet replacing anything).

---

## Phase 3: Propagation

**File:** `walker_propagate.mbt`

### Apply Splice

Modify a parent's children/counts arrays according to a Splice instruction.

```moonbit
/// Apply a splice to children and counts arrays.
/// Returns (span_delta, old_leaf_count_removed, new_leaf_count_added).
fn[T] apply_splice(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  splice : Splice[T],
) -> (Int, Int, Int)
```

Implementation:
1. Compute old_span = sum of counts[start_idx..end_idx)
2. Remove children[start_idx..end_idx) and counts[start_idx..end_idx)
3. Insert new_leaves as Leaf nodes at start_idx (in reverse order for correct positioning)
4. Compute new_span = sum of new spans
5. Return (new_span - old_span, end_idx - start_idx, new_leaves.length())

### Try Merge Boundaries

After a splice, try to merge adjacent leaves at the splice boundaries.

```moonbit
/// After a splice inserted new leaves at [start_idx .. start_idx + count),
/// try merging at the left and right boundaries.
/// Returns the net change in leaf count from merging.
fn[T : @rle.Spanning + @rle.Mergeable] try_merge_boundaries(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  start_idx : Int,
  count : Int,
) -> Int
```

Implementation:
1. If `start_idx + count < children.length()`, try `try_merge_right(children, counts, start_idx + count - 1)` — merge last new leaf with right neighbor
2. If `start_idx > 0`, try `try_merge_right(children, counts, start_idx - 1)` — merge left neighbor with first new leaf
3. Return total leaf_delta from merges (each successful merge = -1)

Note: `try_merge_right` already exists in insert.mbt. Extract it to utils.mbt or walker_propagate.mbt.

### Maybe Split

Check if an Internal node has overflowed and split if needed.

```moonbit
/// If children exceeds 2 * min_degree, split into two Internal nodes.
fn[T] maybe_split(
  children : Array[OrderNode[T]],
  counts : Array[Int],
  total : Int,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?)
```

This wraps the existing `split_internal` function.

### Propagate

The main propagation function. Walks the path from leaf's parent up to root, applying changes at each level.

```moonbit
/// Propagate a splice upward through the cursor's path.
/// Handles: splice application, boundary merging, total recomputation, overflow splits.
fn[T : @rle.Spanning + @rle.Mergeable] propagate(
  cursor : Cursor[T],
  splice : Splice[T],
  min_degree : Int,
) -> PropagateResult[T]
```

Implementation:

```
1. Start at leaf's parent (last PathFrame in cursor.path)
2. Apply splice to parent's children/counts
3. Try merge at boundaries
4. Recompute total
5. Check overflow → maybe_split

6. Walk remaining path frames (from second-to-last to first):
   a. Replace the child we descended into with the rebuilt node
   b. If there was an overflow sibling, insert it after
   c. Update counts for the modified children
   d. Recompute total
   e. Check overflow → maybe_split

7. Return final node + optional overflow + cumulative leaf_delta + span_delta
```

### Tests

```moonbit
test "apply_splice insert before" {
  // children = [Leaf(a, 3), Leaf(b, 5)], splice = Splice(0, 0, [(x, 2)])
  // Result: [Leaf(x, 2), Leaf(a, 3), Leaf(b, 5)], span_delta = +2
}

test "apply_splice delete" {
  // children = [Leaf(a, 3), Leaf(b, 5), Leaf(c, 2)], splice = Splice(1, 2, [])
  // Result: [Leaf(a, 3), Leaf(c, 2)], span_delta = -5
}

test "apply_splice replace" {
  // children = [Leaf(a, 3)], splice = Splice(0, 1, [(a', 4)])
  // Result: [Leaf(a', 4)], span_delta = +1
}

test "try_merge_boundaries" {
  // After insert, adjacent leaves that can_merge should be merged
  // Test with mergeable and non-mergeable neighbors
}

test "propagate single level" {
  // Build a 1-level cursor, apply a splice, verify result
}

test "propagate multi level with split" {
  // Build a cursor deep enough that propagation triggers a split
}
```

**Exit criterion:** All propagation tests pass. Existing order-tree tests still pass.

---

## Phase 4: Rewrite Navigate

**File:** `navigate.mbt` (replace existing content)

The simplest operation. No prepare hook, no splice, just descent + read.

```moonbit
fn[T] OrderNode::navigate(self : OrderNode[T], pos : Int) -> FindResult[T]? {
  // No prepare needed, no min_degree needed for navigate
  let cursor = descend(
    self,
    pos,
    min_degree=0,  // unused since prepare is no-op
    prepare=fn(_children, _counts, _idx, _min_degree) { () },
    find_slot_fn=find_slot,
  )?
  Some({ elem: cursor.leaf_elem, offset: cursor.offset })
}
```

If `descend` returns `None`, the `?` propagates it. Three lines of meaningful code.

**Exit criterion:** ALL existing navigate-related tests pass. Run `moon test` on the full test suite.

---

## Phase 5: Leaf Action Functions (Pure RLE Logic)

**Files:** `walker_insert.mbt`, `walker_delete.mbt`

These are the operation-specific pure functions that compute splices. They contain the RLE merge/split/slice logic extracted from the current insert.mbt and delete.mbt.

### walker_insert.mbt

```moonbit
/// Compute the splice for inserting `new_elem` at the cursor position.
/// This is a pure function — it reads LeafContext but does not modify the tree.
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] compute_insert_splice(
  ctx : LeafContext[T],
  new_elem : T,
) -> Splice[T]
```

Implementation (the RLE logic, restructured):

```
let new_span = Spanning::span(new_elem)
let idx = ctx.child_idx

if ctx.offset == 0:
  // Insert before this leaf
  // 1. Try merge new_elem with left neighbor
  if left_neighbor exists AND can_merge(left, new_elem):
    merged = merge(left, new_elem)
    return Splice(idx - 1, idx, [(merged, merged_span)])
    // Note: try_merge_boundaries in propagation will attempt merging
    // the updated left with the current leaf

  // 2. Try merge new_elem with current leaf
  if can_merge(new_elem, ctx.elem):
    merged = merge(new_elem, ctx.elem)
    return Splice(idx, idx + 1, [(merged, merged_span)])

  // 3. No merge — insert new leaf before current
  return Splice(idx, idx, [(new_elem, new_span)])

else if ctx.offset == ctx.span:
  // Insert after this leaf (symmetric to above)
  // 1. Try merge current with new_elem
  // 2. Try merge new_elem with right neighbor
  // 3. No merge — insert after

else:
  // Mid-run insert: slice current leaf, insert between parts
  left_part = slice(ctx.elem, 0, ctx.offset)
  right_part = slice(ctx.elem, ctx.offset, ctx.span)
  // Build chain: [left_part, new_elem, right_part]
  // Try pairwise merges to minimize leaf count
  return Splice(idx, idx + 1, merge_chain([left_part, new_elem, right_part]))
```

Helper:
```moonbit
/// Try to merge a chain of elements pairwise from left to right.
/// Returns the minimized (elem, span) list.
fn[T : @rle.Spanning + @rle.Mergeable] merge_chain(
  elems : Array[T],
) -> Array[(T, Int)]
```

### walker_delete.mbt

```moonbit
/// Compute the splice for deleting one unit at the cursor position.
/// Returns (splice, deleted_element).
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] compute_delete_splice(
  ctx : LeafContext[T],
) -> (Splice[T], T)
```

Implementation:

```
let idx = ctx.child_idx

if ctx.span == 1:
  // Remove entire leaf
  deleted = ctx.elem
  return (Splice(idx, idx + 1, []), deleted)

else if ctx.offset == 0:
  // Delete first unit
  deleted = slice(ctx.elem, 0, 1)
  rest = slice(ctx.elem, 1, ctx.span)
  return (Splice(idx, idx + 1, [(rest, span(rest))]), deleted)

else if ctx.offset == ctx.span - 1:
  // Delete last unit
  deleted = slice(ctx.elem, ctx.span - 1, ctx.span)
  rest = slice(ctx.elem, 0, ctx.span - 1)
  return (Splice(idx, idx + 1, [(rest, span(rest))]), deleted)

else:
  // Mid-run delete: remove unit at offset, try merge halves
  deleted = slice(ctx.elem, ctx.offset, ctx.offset + 1)
  left_part = slice(ctx.elem, 0, ctx.offset)
  right_part = slice(ctx.elem, ctx.offset + 1, ctx.span)
  if can_merge(left_part, right_part):
    merged = merge(left_part, right_part)
    return (Splice(idx, idx + 1, [(merged, span(merged))]), deleted)
  else:
    return (Splice(idx, idx + 1, [(left_part, span(left_part)), (right_part, span(right_part))]), deleted)
```

### Tests (unit tests for pure functions, no tree needed)

```moonbit
test "compute_insert_splice before leaf no merge" {
  // LeafContext with elem="B", offset=0, no left neighbor
  // Insert "A" (not mergeable with "B")
  // Expected: Splice(idx, idx, [("A", 1)])
}

test "compute_insert_splice merge with left" {
  // LeafContext with elem="C", offset=0, left_neighbor="A"
  // Insert "B" where can_merge("A", "B") is true
  // Expected: Splice(idx-1, idx, [("AB", 2)])
}

test "compute_insert_splice mid-run" {
  // LeafContext with elem="AAAA", span=4, offset=2
  // Insert "B"
  // Expected: Splice(idx, idx+1, [("AA", 2), ("B", 1), ("AA", 2)])
}

test "compute_delete_splice remove entire" {
  // LeafContext with span=1
  // Expected: Splice(idx, idx+1, [])
}

test "compute_delete_splice mid-run mergeable halves" {
  // LeafContext with elem="ABBA", span=4, offset=2
  // Delete at 2, left="AB" right="A", if mergeable → Splice with [(merged, 3)]
}
```

**Exit criterion:** All leaf action unit tests pass. These tests do NOT depend on tree construction — they test pure functions with manually constructed LeafContext values.

---

## Phase 6: Rewrite Insert

**File:** `insert.mbt` (replace the core logic)

Keep the existing `split_internal` function (it's used by prepare_split and propagation). Rewrite `insert_into_internal` and `OrderNode::insert` using the walker.

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderNode::insert(
  self : OrderNode[T],
  pos : Int,
  elem : T,
  min_degree : Int,
) -> (OrderNode[T], OrderNode[T]?, Int) {
  // 1. Descend with proactive splitting
  let cursor = descend(
    self,
    pos,
    min_degree,
    prepare=prepare_split,
    find_slot_fn=find_slot_inclusive,
  ).unwrap()  // pos is already clamped by caller

  // 2. Compute leaf action (pure RLE logic)
  let ctx = LeafContext::from_cursor(cursor)
  let splice = compute_insert_splice(ctx, elem)

  // 3. Propagate
  let result = propagate(cursor, splice, min_degree)
  (result.node, result.overflow, result.leaf_delta)
}
```

The `OrderTree::insert_at` method (which handles the root-level pre-split and empty tree case) stays largely unchanged — it still calls `OrderNode::insert`.

**Exit criterion:** ALL existing insert tests pass. Run the full test suite including `order_tree_test.mbt` and `invariant_wbtest.mbt`.

---

## Phase 7: Rewrite Delete

**File:** `delete.mbt` (replace the core logic)

Keep `borrow_from_left`, `borrow_from_right`, `merge_children`, `ensure_min_children` — these are used by `prepare_ensure_min`. Rewrite `OrderNode::delete`.

```moonbit
fn[T : @rle.Spanning + @rle.Mergeable + @rle.Sliceable] OrderNode::delete(
  self : OrderNode[T],
  pos : Int,
  min_degree : Int,
) -> (OrderNode[T], T?, Int) {
  // 1. Descend with ensure-min-children
  let cursor = descend(
    self,
    pos,
    min_degree,
    prepare=prepare_ensure_min,
    find_slot_fn=find_slot,
  ).unwrap()

  // 2. Compute leaf action (pure RLE logic)
  let ctx = LeafContext::from_cursor(cursor)
  let (splice, deleted) = compute_delete_splice(ctx)

  // 3. Propagate
  let result = propagate(cursor, splice, min_degree)
  (result.node, Some(deleted), result.leaf_delta)
}
```

`OrderTree::delete_at` stays largely unchanged.

**Exit criterion:** ALL existing delete tests pass, including edge cases in `order_tree_test.mbt` and property tests in `properties_wbtest.mbt`.

---

## Phase 8: Cleanup

1. Remove dead code from old insert.mbt and delete.mbt (the inlined descent/propagation logic)
2. Move `try_merge_right` to walker_propagate.mbt (it's now used by the propagation layer)
3. Move `split_internal` to walker_propagate.mbt
4. Run `moon fmt` on all files
5. Run full test suite one final time
6. Verify no compiler warnings

---

## Completion Checklist

- [ ] Phase 0: MoonBit patterns verified
- [ ] Phase 1: Core types compile, LeafContext helpers tested
- [ ] Phase 2: Descent works, find_slot tested, descend tested
- [ ] Phase 3: Propagation works, splice/merge/split tested
- [ ] Phase 4: Navigate rewritten, ALL existing tests pass
- [ ] Phase 5: Leaf action functions tested in isolation
- [ ] Phase 6: Insert rewritten, ALL existing tests pass
- [ ] Phase 7: Delete rewritten, ALL existing tests pass
- [ ] Phase 8: Dead code removed, formatted, final test pass
- [ ] Line count of insert.mbt + delete.mbt reduced by >50%

## Risk Mitigation

**Biggest risk:** The `prepare` hook (proactive split / ensure_min_children) mutates the children/counts arrays. After the hook runs, the child_idx used for descent may be invalid. The current code handles this with re-finding after split (lines 265-269 in insert.mbt) and re-finding after merge (lines 276-284 in delete.mbt). The `descend` function MUST re-find the slot after calling prepare.

**Second risk:** Mutable array aliasing. `PathFrame` stores references to the same `children` and `counts` arrays that the parent Internal node owns. Propagation modifies these arrays in place. This is intentional (it's how the current code works), but the agent must not create copies — the whole point is that modifications at the leaf level are visible to the parent frame.

**Third risk:** The `find_slot_inclusive` vs `find_slot` distinction. Insert uses inclusive boundary (pos at boundary goes to current slot) while navigate/delete use strict boundary (pos at boundary goes to next slot). Mixing these up will cause off-by-one errors in insert. The `descend` function takes `find_slot_fn` as a parameter to handle this.

## Notes for the Agent

- Preserve git history: commit after each phase
- Run `moon test` after EVERY change, not just at phase boundaries
- If a test fails after rewriting, diff against the old implementation to find the behavioral difference
- The `@rle` traits (Spanning, Mergeable, Sliceable) are external — do not modify them
- `must_slice` in utils.mbt is a convenience wrapper — keep using it in leaf actions
- The existing `find_by_sum` / `find_by_sum_inclusive` on ArrayView can be replaced by the new `find_slot` / `find_slot_inclusive` functions, but keep the old ones until all phases are complete
