# Compact Import Section

## Problem

The binary format for the import section today must redundantly specify both the module name and item name for each import. For example, a module that has 1000 imports from an "env" module will have 1000 copies of the "env" string in the binary.

This problem is exacerbated by [JS String Builtins](https://github.com/WebAssembly/js-string-builtins), as modules can have a very large number of imports to handle all the string constants needed in the module. This can be mitigated somewhat by network compression, but this cost must still be paid at parsing time after decompression.

In addition, the JS API specifies an algorithm for ["reading the imports"](https://webassembly.github.io/spec/js-api/#read-the-imports) which suffers from the redundancy in the binary format. For every import we must issue two separate [[Get]] operations. In practice the first one is redundant and could be optimized away; however, [[Get]] is observable to JS code and so special care must be taken to only skip it if nothing could observe it.

## Proposal

This proposal aims to solve this problem through a small change to the binary format, encoding the module name only once, followed by a list of `(item name, externtype)` pairs. (Currently imports are encoded as `(module name, item name, externtype)` triples.)

### Syntax

The AST for imports is extended to include both "imports" and "import modules", separating the module and item names:

```
;; Before
import ::== name name externtype
module ::== ... import* ...

;; After
import    ::== name externtype
importmod ::== name import*
module    ::== ... importmod* ...
```

### Binary

An import module with multiple imports is encoded by: the byte sequence `0x01 0xFF`, the module name, and a [list](https://webassembly.github.io/spec/core/binary/conventions.html#binary-list) (vec) of imports. The previous encoding is redefined to produce an import module with a single import.

The byte sequence `0x01 0xFF` will be decoded by existing implementations as an invalid [`name`](https://webassembly.github.io/spec/core/binary/values.html#binary-name) consisting only of `0xFF`. Since `0xFF` is not valid in UTF-8, this name should always be rejected by current implementations, and the new encoding is therefore backwards-compatible. Additionally, no new section ID is required.

```
;; Before
importsec ::== section_2(list(import))
import    ::== name name externtype

;; After
importsec ::== section_2(list(importmod))
importmod ::== name import                  ;; single-item encoding (existing)
             | 0x01 0xFF name list(import)  ;; multiple-item compact encoding
import    ::== name externtype
```

### Text format

The `import` keyword is redefined to produce an import module instead of an import. Individual imports within a module are specified with `(item ...)`. The existing `(import "foo" "bar" ...)` syntax is included as an abbreviation for `(import "foo" (item "bar" ...))`.

```
;; Before
(import "mod" "foo" ...)
(import "mod" "bar" ...)

;; After
(import "mod" (item "foo" ...) (item "bar" ...))
```

The existing import abbreviations, e.g. `(global (import "foo" "bar") ...)`, will continue to use the non-compact encoding.

It is expected that the different text encodings and the different binary encodings will be one-to-one; that is, the `item` format always corresponds to the compact import encoding, and the legacy abbreviation always corresponds to the non-compact encoding. This ensures that data will round-trip correctly through the text format.

### Validation & Execution

No significant changes are necessary to validation and execution.

### JS API

The ["read the imports"](https://webassembly.github.io/spec/js-api/index.html#read-the-imports) step in the JS API is updated to perform one [[Get]] per import module name and one [[Get]] per import name within an import module.


## Alternatives

TODO
