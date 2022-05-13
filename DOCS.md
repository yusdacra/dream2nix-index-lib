### `indexTree`

An "index tree" is a source tree with the following hierarchy:

```
+ index.json: an index
+ locks:
  - "zstd/0.11.2+zstd.1.5.2/dream-lock.json": path to a dream-lock
  - "<package name>/<package version>/dream-lock.json"
```

### `index`

An "index" is a package set with names, versions and (optionally) hashes.

Example:

```json
{
  "wasm-bindgen": {
    "0.2.80": "27370197c907c55e3f1a9fbe26f44e937fe6451368324e009cba39e139dc08ad"
  }
}
```