# order-tree

Position-indexed sequence for [MoonBit](https://www.moonbitlang.com/) with O(log n) lookup by index and O(log n) point mutations when boundary merges are bounded.

Built on [`dowdiness/btree`](https://mooncakes.io/docs/dowdiness/btree@0.3.0) (a counted B+ tree). OrderTree adds a high-level API for common sequence operations — insert at position, delete at position, bulk construction from arrays, and operator overloads.

## Install

Version 0.3.0 targets MoonBit compiler/core `0.10.21+06da1ed44`.
Use published btree 0.3.0, rle 0.4.0 and QuickCheck 0.15.1; no local overrides are needed.
See [CHANGELOG.md](CHANGELOG.md) for the compiler and dependency migration.

```bash
moon add dowdiness/order-tree
```

## Quick Start

```moonbit
// Build from array
let tree = @order_tree.OrderTree::from_array(["a", "b", "c", "d"])

// Positional access
tree[0]       //=> Some("a")
tree[2]       //=> Some("c")

// Range view
tree[1:3]     //=> ["b", "c"]

// Insert and delete
tree.insert_at(2, "x")    // ["a", "b", "x", "c", "d"]
tree.delete_at(0)          //=> Some("a"), tree is ["b", "x", "c", "d"]

// Range delete
tree.delete_range(1, 3)    // ["b", "d"]
```

## API

| Method | Description | Complexity |
|--------|-------------|------------|
| `OrderTree::new(min_degree?)` | Create empty tree | O(1) |
| `OrderTree::from_array(items, min_degree?)` | Bulk build from array | O(n) |
| `get_at(pos)` / `tree[pos]` | Element at position | O(log n) |
| `find(pos)` | Element + offset within element | O(log n) |
| `insert_at(pos, elem)` | Insert element at position; non-positive spans are ignored | O((m + 1) log n)¹ |
| `delete_at(pos)` | Delete element at position | O((m + 1) log n)¹ |
| `delete_range(start, end)` | Delete span range [start, end) | O(log n) |
| `set_at(pos, elem)` / `tree[pos] = elem` | Replace element; non-positive spans are rejected without mutation | O((m + 1) log n)¹ |
| `view(start?, end?)` / `tree[start:end]` | Slice elements in range | O(k + log n) |
| `iter()` | Lazy iterator over all elements | O(n) total |
| `span()` | Total span | O(1) |
| `size()` | Number of RLE runs (≤ logical length when adjacent items merge) | O(1) |

¹ Point mutations normalize only their affected logical boundaries. Here `m` is
  the number of boundaries merged into the canonical run closure; the common
  bounded-merge case remains O(log n).

## When to Use OrderTree vs BTree

| Need | Use |
|------|-----|
| Insert/delete by position | `OrderTree` — `insert_at`, `delete_at` |
| Bulk construction from array | `OrderTree` — `from_array` (O(n) bottom-up) |
| Operator syntax (`tree[i]`, `tree[i:j]`) | `OrderTree` — has `#alias` overloads |
| Custom splice logic (split/merge neighbors) | `BTree` — `mutate_for_insert/delete` callbacks |
| Embedding in another data structure | `BTree` — `OrderTree` is a thin wrapper |

OrderTree is a single-field wrapper: `{ tree: @btree.BTree[T] }`. It delegates all operations to the underlying BTree and adds convenience methods.

## Element Requirements

Trait bounds scale with the operation:

- **Pure queries** (`get_at` / `tree[pos]`, `find`, `size`, `span`, `each`, `to_array`, `iter`, `length`, `is_empty`): no bound on `T`.
- **Bulk construction** (`from_array`): `@rle.Spanning + @rle.Mergeable`.
- **Positional mutation and slicing** (`insert_at`, `delete_at`, `delete_range`, `set_at` / `tree[pos] = item`, `view` / `tree[start:end]`): `@btree.BTreeElem`, the super trait `@rle.Spanning + @rle.Mergeable + @rle.Sliceable`.

`view` needs `Sliceable` because it may split an element at a span boundary when materializing the slice — not because it mutates.

Elements passed to `insert_at` with a span of zero or less are ignored. For
`set_at`, the same invalid replacement returns `None` and leaves the tree
unchanged; the index setter is likewise a no-op.

Traits:
- `@rle.Spanning` — how much span an element occupies
- `@rle.Mergeable` — when adjacent elements can merge (RLE compression)
- `@rle.Sliceable` — how to split an element at a position

See [`dowdiness/rle`](https://mooncakes.io/docs/dowdiness/rle@0.4.0) for trait details.

Custom elements must implement `Sliceable::slice(...) -> Self raise @rle.RleError`,
not return a `Result`. Return successful slices directly and raise the same
errors formerly returned as `Err`. OrderTree's public method signatures remain
infallible; slicing failure at an internally navigated position still aborts.

## Defining Your Element Type

To use mutation and slicing operations you need an element type that implements `@btree.BTreeElem`. Add the dependencies that contribute the traits:

```bash
moon add dowdiness/order-tree
moon add dowdiness/rle
moon add dowdiness/btree
```

```moonbit
// Each E occupies span 1 and never merges with its neighbour.
#derive(Eq)
pub struct E {
  v : Int32
}

pub impl @rle.HasLength for E with length(_self) { 1 }

pub impl @rle.Spanning for E with span(_self) { 1 }

pub impl @rle.Mergeable for E with can_merge(_a, _b) { false }
pub impl @rle.Mergeable for E with merge(a, _b) { a }

pub impl @rle.Sliceable for E with fn slice(
  self, start~ : Int32, end~ : Int32,
) -> E raise @rle.RleError {
  if start != 0 || end != 1 {
    raise @rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex)
  }
  self
}

// BTreeElem is an empty super-trait. MoonBit emits warning [0027]
// for implicit empty-trait impls, so add an explicit one:
pub impl @btree.BTreeElem for E
```

For RLE-merging behaviour (adjacent runs of the same value collapse to a single leaf), make `can_merge` return `true` for compatible neighbours and have `merge` combine their spans. See `dowdiness/rle` for the full contract.

## Architecture

```
dowdiness/rle          Element traits (Spanning, Mergeable, Sliceable)
    ↑
dowdiness/btree        Counted B+ tree engine
    ↑                  - Navigation by span position (not keys)
    |                  - All data in leaves, internal nodes are navigational
    |                  - Automatic RLE merge of adjacent leaves
    |
dowdiness/order-tree   High-level sequence API (this library)
                       - insert_at, delete_at, from_array
                       - Operator overloads
                       - Used by the CRDT layer (event-graph-walker)
```

## Design Notes

The underlying B+ tree uses **span counts** instead of keys for navigation. Each internal node stores a `counts` array where `counts[i]` is the total span of child `i`. This gives O(log n) positional access without key comparison — ideal for sequence editors where position is the natural index.

Adjacent elements with the same identity merge automatically (RLE compression). This keeps the tree compact when consecutive elements share properties (e.g., same author, same formatting).

## Verification

CI pins compiler and core to `0.10.21+06da1ed44`. Run:

```bash
moon update
moon check --target all --fmt --deny-warn
moon info --frozen
moon build --target all --deny-warn --frozen
moon build --target all --release --deny-warn --frozen
moon test --target all --frozen
moon test --target all --release --frozen
moon bench --target all --release --build-only --deny-warn --frozen
moon doc --frozen
moon package --list --frozen
```

CI also extracts the distribution ZIP and runs warning-denied checks/builds
and generates docs from it. The rle 0.4.0 typed-raise migration removes the
former `Result`-returning `Sliceable` implementations; no new warning
suppression or reduced test matrix is used.
