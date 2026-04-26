# Changelog

## 0.1.0 — Initial release

First tagged release of `order-tree`: a positional B-tree with run-length-encoded leaves for ordered collections. Thin wrapper over [`dowdiness/btree`](https://mooncakes.io/docs/dowdiness/btree@0.1.0); uses element traits from [`dowdiness/rle`](https://mooncakes.io/docs/dowdiness/rle@0.2.0).

### Public API

Constructors:
- `OrderTree::new(min_degree?)` — empty tree (default min_degree = 10, clamped to ≥ 2).
- `OrderTree::from_array(items, min_degree?)` — O(n) bulk build; filters zero-span items and pre-merges adjacent mergeable elements before building bottom-up.

Queries (no trait bound on `T`):
- `get_at(pos) -> T?` / `tree[pos]` — element at span position; `None` when out of range.
- `find(pos) -> @btree.FindResult[T]?` — element plus offset within the run.
- `size() -> Int` — number of RLE runs (≤ logical length when adjacent items merge).
- `each(f)`, `to_array()`, `iter()` — traversal.
- `@rle.HasLength` impl: `length()`, `is_empty()`.
- `@rle.Spanning` impl: `span()` (O(1), cached root total), `logical_length()`.

Positional mutation and slicing (require `T : @btree.BTreeElem`):
- `insert_at(pos, item)`, `delete_at(pos) -> T?`, `delete_range(start, end)`.
- `set_at(pos, item) -> T?` / `tree[pos] = item` — returns the previous element (when in range).
- `view(start? = 0, end? = length) -> Array[T]` / `tree[start:end]`, `tree[:end]`, `tree[start:]`, `tree[:]` — materialized slice; one descent plus leaf walk.

### Element requirements

Trait bounds scale with the operation:

| Operation set                                                                 | Bound                                              |
| ----------------------------------------------------------------------------- | -------------------------------------------------- |
| Pure queries (`get_at`, `find`, `size`, `span`, `each`, `to_array`, `iter`, …) | None                                               |
| `from_array`                                                                  | `@rle.Spanning + @rle.Mergeable`                   |
| Positional mutation *and* `view` (materializes slices)                        | `@btree.BTreeElem` (= `Spanning + Mergeable + Sliceable`) |

`view` needs `Sliceable` because it may split an element at a span boundary when materializing the slice — not because it mutates.

### Implementation notes

Built on `@btree.BTree[T]` as a single-field wrapper; positional mutation, slicing, and range delete delegate to the underlying B-tree. Leaves hold one element each, with merge/split handled at RLE boundaries. Built and tested with `moon 0.1.20260409`.
