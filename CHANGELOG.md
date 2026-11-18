# Changelog

## 0.3.0 — 2026-11-18

### Breaking changes

- Adopt published `dowdiness/btree@0.3.0` and `dowdiness/rle@0.4.0`.
  Custom elements must implement `Sliceable::slice` as
  `Self raise RleError` instead of `Result[Self, RleError]`: return successful
  slices directly and raise the same errors instead of returning `Err`.
- Continue targeting MoonBit compiler/core `0.10.21+06da1ed44`.

### Changed

- Update QuickCheck to published `0.15.1`; all direct and transitive dependency
  requirements now agree.
- Adapt the internal slice boundary to typed errors while preserving its
  existing abort behavior and message. OrderTree method names, signatures,
  bounds, mutation algorithms and allocation policy are unchanged.
- Migrate test and benchmark fixtures without changing their accepted ranges,
  produced elements or error variants.
- Make root and extracted-distribution CI checks/builds warning-denied, while
  retaining all four targets, both test modes, benchmark compilation and docs.
  No new warning suppression or test reduction is introduced.

## 0.2.0 — 2026-11-18

### Changed

- Target MoonBit compiler/core `0.10.21+06da1ed44` (latest stable distribution
  when prepared); migrate formatter-generated syntax and generated interfaces.
  Older compilers are not supported by this release.
- Update published dependencies to `dowdiness/rle@0.3.0` and
  `moonbitlang/quickcheck@0.15.0`, retaining `dowdiness/btree@0.2.0`.
- Add CI for all four backends, debug/release tests, benchmark compilation,
  documentation generation, and extracted-package verification.

### Fixed

- Qualify all 16 benchmark calls to `@rle.Spanning::span(tree)` so they no
  longer depend on implicit trait-method lookup during documentation builds.

### Migration

- `Int32` replaces the alias `Int` in generated signatures; numeric widths
  and operation semantics are unchanged. Public method names and bounds remain
  unchanged from main. Earlier unreleased main changes already promote
  existing query traits, equality/debug methods, and the index setter.
- Since published 0.1.2, the named index setter `op_set` has become
  `set_index`. Replace `tree.op_set(pos, value)` with
  `tree.set_index(pos, value)` or `tree[pos] = value`.
- Use `@rle.Spanning::span(tree)` for explicit trait dispatch. Applications
  implementing rle traits must use the published rle 0.3.0 contract.
- `Sliceable::slice` intentionally retains rle's `Result` contract. New
  `result_error_return` migration warnings remain visible; warning-denied
  checks are not claimed successful. No warning suppression was added.

## 0.1.2 — 2026-08-02

### Changed

- Update `dowdiness/btree` from 0.1.0 to 0.2.0.

### Fixed

- Normalize the logical boundaries affected by successful point mutations so
  adjacent mergeable runs remain canonical across B-tree parent boundaries.

## 0.1.1 — 2026-06-23

### Added

- README: "Defining Your Element Type" walkthrough with copy-pasteable example
  covering all four RLE trait impls and the `BTreeElem` super trait. [64dc573]

### Changed

- Migrate to MoonBit v0.10+ project layout: `moon.mod.json` → TOML `moon.mod`,
  packages moved from `src/` to module root. [1359250]
- Update `rle` dependency 0.2.0 → 0.2.2 and `quickcheck` 0.11.2 → 0.14.0. [cf42767]

### Fixed

- README: remove stale claim that `delete_range` "falls back to O(n) rebuild";
  the operation delegates to `@btree.BTree` with no such fallback in this layer.
- Archive two superseded plan files describing a walker architecture that was
  replaced by the thin `@btree.BTree[T]` wrapper pattern.

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
