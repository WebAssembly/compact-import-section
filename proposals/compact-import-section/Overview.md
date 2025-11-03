# Compact Import Section

## Problem

The binary format for the import section today must redundantly specify both the module name and item name for each import. For example, a module that has 1000 imports from an "env" module will have 1000 copies of the "env" string in the binary.

This problem is exacerbated by [JS String Builtins](https://github.com/WebAssembly/js-string-builtins), as modules can have a very large number of imports to handle all the string constants needed in the module. This can be mitigated somewhat by network compression, but this cost must still be paid at parsing time after decompression.

## Proposal

This proposal aims to solve this problem through a small change to the binary format, encoding the module name only once, followed by a list of `(item name, externtype)` pairs. (Currently imports are encoded as `(module name, item name, externtype)` triples.)

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

### Syntax, Validation, Execution

No changes are made to the syntax, validation, or execution sections.


## Alternatives

### Update the AST of modules

It would be possible to manifest this change in the structure of a WebAssembly module like so:

```
;; Before
import ::== name name externtype
module ::== ... import* ...

;; After
import    ::== name externtype
importmod ::== name import*
module    ::== ... importmod* ...
```

Depending on implementation, this could potentially reduce the size of modules in memory. In addition, the ["read the imports"](https://webassembly.github.io/spec/js-api/#read-the-imports) section of the JS API could be updated to reflect the AST, dispatching only one [[Get]] to the imports object for each `importmod`, resulting in fewer object accesses overall. This could potentially have performance improvements in JS engines.

However, this change to the AST would complicate various aspects of the spec, including some changes to validation and execution, and particularly impacting the `module_imports` function in the Embedding appendix. In addition, it clashes with existing host APIs for imports, particularly the JS API's [Module.imports](https://webassembly.github.io/spec/js-api/index.html#dom-module-imports) function, which returns `{"module": "...", "name": "...", "kind": "..."}` triples. It would presumably be best to change the return value of this function if the structure of imports were to change, but this would be a quite incompatible change.

### Add a new section ID

Instead of using an invalid `name` (`0x01 0xFF`) to signify a run of compact imports, we could introduce a new section ID to the binary encoding. This would result in a cleaner and (very) slightly more compact encoding, but both forms of the import section would need to remain in the spec.

Also, if adding a new section ID, it is less clear how the binary encoding would map to the text encoding. This proposal specifies that `(import "foo" (item "bar" ...))` will use the compact encoding, and `(import "foo" "bar" ...)` will use the non-compact encoding. Consider, then, this set of imports in the text format:

```
(import "foo" "bar" ...)
(import "baz" (item "im1" ...) (item "im2" ...))
(import "beep" "boop" ...)
```

If the encodings are mixed, but must appear in separate sections, then it will not be possible to preserve the order of imports when round-tripping through the binary format. Either additional ordering information would be required, which would be superfluous, or perhaps the non-`(item)` form would simply use the compact encoding as well, which may actually bloat the binary due to the sentinel name appearing repeatedly.
