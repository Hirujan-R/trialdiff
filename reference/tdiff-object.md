# The `tdiff` object

[`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md)
returns an object of class `tdiff`. It is a list with the following
elements:

## Details

- `meta`: comparison metadata (dataset, cut names, keys, row counts,
  time).

- `added`: observations present in the new cut but not the old cut, with
  `.key` and `.subject` helper columns.

- `removed`: observations present in the old cut but not the new cut.

- `modified`: one row per changed cell, with `variable`, `old_value`,
  `new_value` and `change` (`"value"`, `"missing_to_value"` or
  `"value_to_missing"`).

- `schema`: variable-level changes (`variable_added`,
  `variable_removed`, `type_change`, `label_change`).

- `summary`: a tidy metric/value table.
