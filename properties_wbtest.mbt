///|
test "property: insert then get roundtrip" {
  @qc.quick_check_fn(fn(size : Int) -> Bool {
    let r = size % 50
    let size = if r < 0 { -r } else { r }
    let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
    for i = 0; i < size; i = i + 1 {
      tree.insert_at(i, mki(i))
    }
    for i = 0; i < size; i = i + 1 {
      match tree.get_at(i) {
        Some(item) => if item.value != i { return false }
        None => return false
      }
    }
    true
  })
}

///|
test "property: delete reduces span" {
  let tree : OrderTree[TI] = OrderTree::new(min_degree=2)
  for i = 0; i < 30; i = i + 1 {
    tree.insert_at(i, mki(i))
  }
  for i = 0; i < 30; i = i + 1 {
    let before = tree.span()
    ignore(tree.delete_at(0))
    let after = tree.span()
    @debug.debug_inspect(before - after == 1, content="true")
  }
}

///|
test "property: from_array then to_array roundtrip" {
  @qc.quick_check_fn(fn(size : Int) -> Bool {
    let r = size % 100
    let size = if r < 0 { -r } else { r }
    let items = Array::makei(size, fn(i) { mki(i) })
    let tree = OrderTree::from_array(items, min_degree=2)
    let result = tree.to_array()
    if result.length() != size {
      return false
    }
    for i = 0; i < size; i = i + 1 {
      if result[i].value != i {
        return false
      }
    }
    true
  })
}

///|
test "property: random operations including invalid set_at maintain invariants" {
  @qc.quick_check_fn(fn(ops : Array[Int]) -> Bool {
    let tree = OrderTree::from_array([mki(0)], min_degree=2)
    let generated_limit = if ops.length() > 200 { 200 } else { ops.length() }
    // Two synthetic operations make both invalid spans run even for an empty
    // generated array. Keeping at least one item makes every set_at position
    // valid instead of allowing a vacuous success.
    let limit = generated_limit + 2
    for i = 0; i < limit; i = i + 1 {
      let v = if i < generated_limit { ops[i] } else { i }
      let op_type = Int::abs(v % 3)
      if tree.span() <= 1 || op_type != 0 {
        let pos = Int::abs(v % (tree.span() + 1))
        tree.insert_at(pos, mki(i))
      } else {
        let pos = Int::abs(v % tree.span())
        ignore(tree.delete_at(pos))
      }
      let valid_pos = Int::abs(v % tree.span())
      let invalid_span = if i % 2 == 0 { 0 } else { -1 }
      let before_content = tree
        .to_array()
        .map(item => (item.value, item.item_span))
      let before_span = tree.span()
      let before_size = tree.size()
      let before_invariants = check_invariants(tree)
      if before_invariants is Some(_) ||
        tree.set_at(valid_pos, { value: invalid_span, item_span: invalid_span })
        is Some(_) ||
        tree.to_array().map(item => (item.value, item.item_span)) !=
        before_content ||
        tree.span() != before_span ||
        tree.size() != before_size ||
        check_invariants(tree) != before_invariants {
        return false
      }
    }
    true
  })
}

///|
test "property: invalid set_at preserves non-empty tree state" {
  @qc.quick_check_fn(fn(ops : Array[Int]) -> Bool {
    let limit = if ops.length() > 200 { 200 } else { ops.length() }
    let items = Array::makei(limit + 1, i => {
      if i == 0 {
        mki(0)
      } else {
        mki(ops[i - 1])
      }
    })
    let tree = OrderTree::from_array(items, min_degree=2)
    let seed = if ops.length() == 0 { 0 } else { ops[0] }
    let remainder = seed % tree.span()
    let pos = if remainder < 0 { -remainder } else { remainder }
    let cases = [(0, pos), (-1, (pos + 1) % tree.span())]
    for case in cases {
      let (invalid_span, valid_pos) = case
      let before_content = tree
        .to_array()
        .map(item => (item.value, item.item_span))
      let before_span = tree.span()
      let before_size = tree.size()
      let before_invariants = check_invariants(tree)
      if before_invariants is Some(_) ||
        tree.set_at(valid_pos, { value: invalid_span, item_span: invalid_span })
        is Some(_) ||
        tree.to_array().map(item => (item.value, item.item_span)) !=
        before_content ||
        tree.span() != before_span ||
        tree.size() != before_size ||
        check_invariants(tree) != before_invariants {
        return false
      }
    }
    true
  })
}

///|
fn bounded(seed : Int, bound : Int) -> Int {
  let remainder = seed % bound
  if remainder < 0 {
    remainder + bound
  } else {
    remainder
  }
}

///|
fn flatten_runs(items : Array[Run]) -> Array[String] {
  items.iter().flat_map(item => [item.ch].repeat(item.span).iter()).collect()
}

///|
fn insert_model_span(
  model : Array[String],
  pos : Int,
  value : String,
  span : Int,
) -> Unit {
  Array::makei(span, _ => value).eachi((offset, item) => {
    model.insert(pos + offset, item)
  })
}

///|
fn build_run_tree(model : Array[String], degree_case : Int) -> OrderTree[Run] {
  let items = model[:]
    .chunk_by((left, right) => left == right)
    .map(chunk => run(chunk[0], chunk.length()))
  match degree_case {
    0 => OrderTree::from_array(items, min_degree=2)
    1 => OrderTree::from_array(items, min_degree=3)
    _ => OrderTree::from_array(items)
  }
}

///|
fn planned_insert(
  model : Array[String],
  direction : Int,
  step : Int,
  seed : Int,
) -> (Int, String) {
  if model.length() == 0 {
    return (0, "insert-\{step}-\{seed}")
  }
  let chunks = model[:].chunk_by((left, right) => left == right)
  let first_boundary = chunks[0].length()
  match direction {
    0 => {
      let pos = if chunks.length() > 1 {
        first_boundary
      } else {
        model.length()
      }
      (pos, model[pos - 1])
    }
    1 => {
      let pos = if chunks.length() > 1 { first_boundary } else { 0 }
      (pos, model[pos])
    }
    2 => {
      let pos = if first_boundary > 1 { 1 } else { 0 }
      (pos, model[pos])
    }
    _ => {
      let pos = if chunks.length() > 1 {
        first_boundary
      } else {
        model.length()
      }
      (pos, "insert-\{step}-\{seed}")
    }
  }
}

///|
fn matches_run_model(tree : OrderTree[Run], model : Array[String]) -> Bool {
  let items = tree.to_array()
  let expected_size = if model.length() == 0 {
    0
  } else {
    model[:].chunk_by((left, right) => left == right).length()
  }
  if flatten_runs(items) != model ||
    tree.span() != model.length() ||
    tree.size() != expected_size ||
    check_invariants(tree) is Some(_) ||
    flatten_runs(tree.view(start=0, end=model.length())) != model ||
    flatten_runs(tree.iter().collect()) != model {
    return false
  }
  for pos in 0..<model.length() {
    match tree.get_at(pos) {
      Some(item) => if item.ch != model[pos] { return false }
      None => return false
    }
    match tree.find(pos) {
      Some(found) => if found.elem.ch != model[pos] { return false }
      None => return false
    }
  }
  true
}

///|
test "property: mergeable point mutations match a maximal RLE model" {
  @qc.quick_check_fn(
    fn(ops : Array[Int]) -> Bool {
      let generated_limit = if ops.length() > 40 { 40 } else { ops.length() }
      // These seeds force left-only, right-only, both-side, and neither-side
      // insertion classes even when QuickCheck generates an empty array.
      let required_insert_seeds = [0, 3, 6, 9]
      let limit = generated_limit + required_insert_seeds.length()
      for degree_case in 0..<3 {
        for height_case in 0..<2 {
          let run_count = if height_case == 0 { 5 } else { 70 }
          let model = Array::makei(run_count * 2, index => {
            (index / 2 % 7).to_string()
          })
          let tree = build_run_tree(model, degree_case)
          if !matches_run_model(tree, model) {
            return false
          }
          for step in 0..<limit {
            let seed = if step < generated_limit {
              ops[step]
            } else {
              required_insert_seeds[step - generated_limit]
            }
            let operation = bounded(seed, 3)
            let replacement_span = bounded(seed / 7, 3) + 1
            if operation == 0 || model.length() == 0 {
              let direction = bounded(seed / 3, 4)
              let (pos, value) = planned_insert(model, direction, step, seed)
              tree.insert_at(pos, run(value, replacement_span))
              insert_model_span(model, pos, value, replacement_span)
            } else if operation == 1 {
              let pos = bounded(seed / 3, model.length())
              ignore(tree.delete_at(pos))
              ignore(model.remove(pos))
            } else {
              let pos = bounded(seed / 3, model.length())
              let value = bounded(seed / 11, 7).to_string()
              guard tree.set_at(pos, run(value, replacement_span)) is Some(_) else {
                return false
              }
              ignore(model.remove(pos))
              insert_model_span(model, pos, value, replacement_span)
            }
            if !matches_run_model(tree, model) {
              return false
            }
          }
        }
      }
      true
    },
    max_success=30,
  )
}

///|
test "generated operations cover mutation and topology risk classes" {
  let samples : Array[Array[Int]] = @quickcheck.samples(512)
  let seeds = samples.iter().flat_map(values => values.iter()).collect()
  let operations = [false, false, false]
  let merge_directions = [false, false, false, false]
  let degree_classes = [false, false, false]
  let height_classes = [false, false]
  for seed in seeds {
    let operation = bounded(seed, 3)
    operations[operation] = true
    if operation == 0 {
      merge_directions[bounded(seed / 3, 4)] = true
    }
    degree_classes[bounded(seed / 12, 3)] = true
    height_classes[bounded(seed / 36, 2)] = true
  }
  @debug.debug_inspect(operations.all(reached => reached), content="true")
  @debug.debug_inspect(merge_directions.all(reached => reached), content="true")
  @debug.debug_inspect(degree_classes.all(reached => reached), content="true")
  @debug.debug_inspect(height_classes.all(reached => reached), content="true")
}
