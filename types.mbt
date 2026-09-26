///|
/// Order-statistic B-tree: a position-indexed sequence with O(log n) operations.
/// Items are ordered by insertion position, not by key comparison.
/// Wraps a generic `@btree.BTree[T]` and adds RLE-specific merge semantics.
pub struct OrderTree[T] {
  tree : @btree.BTree[T]
} derive(Debug, Eq)

///|
pub extend OrderTree with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OrderTree with Eq::{equal, not_equal}
