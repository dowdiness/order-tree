# order-tree

Position-indexed sequence for [MoonBit](https://www.moonbitlang.com/) with O(log n) insert, delete, and lookup by index.

Built on [`dowdiness/btree`](https://github.com/dowdiness/canopy/tree/main/lib/btree) (a counted B+ tree). OrderTree adds a high-level API for common sequence operations — insert at position, delete at position, bulk construction from arrays, and operator overloads.

## Install

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
| `OrderTree::from_array(items)` | Bulk build from array | O(n) |
| `get_at(pos)` / `tree[pos]` | Element at position | O(log n) |
| `find(pos)` | Element + offset within element | O(log n) |
| `insert_at(pos, elem)` | Insert element at position | O(log n) |
| `delete_at(pos)` | Delete element at position | O(log n) |
| `delete_range(start, end)` | Delete span range [start, end) | O(log n)* |
| `set_at(pos, elem)` / `tree[pos] = elem` | Replace element | O(log n) |
| `view(start?, end?)` / `tree[start:end]` | Slice elements in range | O(k + log n) |
| `iter()` | Lazy iterator over all elements | O(n) total |
| `span()` | Total span | O(1) |
| `size()` | Number of elements | O(1) |

*Falls back to O(n) rebuild for some boundary cases.

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

Elements must implement `@btree.BTreeElem`, which requires:
- `@rle.Spanning` — how much span an element occupies
- `@rle.Mergeable` — when adjacent elements can merge (RLE compression)
- `@rle.Sliceable` — how to split an element at a position

See [`dowdiness/rle`](https://github.com/dowdiness/canopy/tree/main/rle) for trait details.

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
