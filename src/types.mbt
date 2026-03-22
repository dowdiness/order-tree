///|
/// Result of a position lookup in the tree.
pub struct FindResult[T] {
  elem : T
  offset : Int
} derive(Show, Eq)

///|
/// A node in the order-statistic B-tree.
/// Leaf nodes store a single element with cached span.
/// Internal nodes store children with per-child span counts.
pub(all) enum OrderNode[T] {
  Leaf(elem~ : T, span~ : Int)
  Internal(children~ : Array[OrderNode[T]], counts~ : Array[Int], total~ : Int)
} derive(Show, Eq)

///|
const DEFAULT_MIN_DEGREE : Int = 10

///|
/// Order-statistic B-tree: a position-indexed sequence with O(log n) operations.
/// Items are ordered by insertion position, not by key comparison.
/// Each internal node caches subtree span counts for fast navigation.
pub struct OrderTree[T] {
  mut root : OrderNode[T]?
  min_degree : Int
  mut size : Int
} derive(Show, Eq)
