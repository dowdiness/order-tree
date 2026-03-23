# Benchmark Results

## 2026-03-23

Command run from module root:

```sh
moon bench --release -p dowdiness/order-tree -f order_tree_benchmark.mbt
```

These results were taken from the current working tree after:
- walker-based `view` traversal
- rebuild-based `delete_range`
- added `view` / `delete_range` benchmarks

Key results:

| Benchmark | Result |
| --- | --- |
| `view middle range (1000)` | `27.50 µs ± 0.48 µs` |
| `delete_range middle (1000)` | `65.40 µs ± 2.79 µs` |
| `view middle mergeable (10000)` | `0.11 µs ± 0.00 µs` |
| `delete_range middle mergeable (10000)` | `80.91 µs ± 3.07 µs` |

Relevant comparison points from the same run:

| Benchmark | Result |
| --- | --- |
| `delete_at sequential (1000)` | `463.60 µs ± 10.08 µs` |
| `from_array (10000)` | `333.21 µs ± 7.58 µs` |
| `from_array mergeable (10000)` | `41.36 µs ± 1.08 µs` |

Takeaways:

- Cursor-based `view` looks cheap enough to keep as the default traversal path.
- Rebuild-based `delete_range` appears fast enough to justify its simpler implementation.
- Mergeable benchmarks are dominated by the small number of retained runs, so they should not be compared directly to the non-mergeable shape without noting that structural difference.

Note:

- The codebase later added a guarded in-place `delete_range` fast path, but the
  public API still rebuilds for merge-normalization cases and non-root underflow
  risk. These benchmark numbers therefore remain relevant as the conservative
  baseline rather than the final word on range-delete performance.
