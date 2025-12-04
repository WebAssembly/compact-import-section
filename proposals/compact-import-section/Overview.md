# Compact Import Section

## Problem

The binary format for the import section today must redundantly specify both the module name and item name for each import. For example, a module that has 1000 imports from an "env" module will have 1000 copies of the "env" string in the binary. It is typical in practice for a WebAssembly module to have just a handful of unique module names, even when there are thousands of imports, so the redundant module names are almost always very wasteful.

Additionally, some modules have runs of imports with the same type, e.g. many `(global (mut i32))` for WebGL, or many `(ref extern)` for [JS String Builtins](https://github.com/WebAssembly/js-string-builtins). In such cases, the type could be considered redundant as well, and could be encoded more compactly.

JS String Builtins are the most affected by these problems, as modules can have a very large number of imports to handle all the string constants needed in the module, but every import must spend at least five extra bytes to encode the module name and global type. This adds up quickly in practice.

The redundancy problem can be mitigated to a large degree by network compression, but this cost must still be paid at parsing time after decompression. Additionally, we have found through [testing](https://docs.google.com/spreadsheets/d/1QgA26STK3GRmV10uNqNLvWoHdWhA81sGSVwr0wF_540/edit?gid=0#gid=0) that the bloat does not disappear entirely under compression, and some modules are wasting a few KB even when compressed.

## Proposal

This proposal aims to solve this problem through a small change to the binary format, introducing two new compact encodings for imports. They are:

- One module name and a list of (item name, externtype) pairs.
- One module name, one externtype, and a list of item names.

(Currently imports are always encoded as (module name, item name, externtype) triples.)

### Binary

Both compact encodings begin the same way: the module name, an empty name, and a byte to signify the compact encoding being used, either `0x7F` or `0x7E` (occurring in the same place as the current encoding's externtype). The required item names and externtypes are then encoded straightforwardly. The previous encoding remains valid and still encodes a single import.

```
;; Before
importsec ::== section_2(list(import))
import    ::== nm1:name nm2:name externtype

;; After
importsec ::== section_2(list(imports))
imports   ::== nm1:name nm2:name externtype                                   ;; single-item encoding (existing)
             | nm1:name nm:name 0x7F list(nm2:name externtype)  -- if nm = "" ;; compact encoding 1
             | nm1:name nm:name 0x7E externtype list(nm2:name)  -- if nm = "" ;; compact encoding 2
```

The `0x7F` or `0x7E` will cause existing implementations to fail with "unknown import type" or similar, making this change backward-compatible. The values are chosen so that this byte may be reinterpreted as LEB128 in the future.

The expected overall cost of this encoding scheme is just three or four bytes: `0x00` for the empty name, `0x7F` or `0x7E` to signal a compact encoding, and likely no more than two bytes for the number of import items to follow. As any redundant module name or externtype must be at least one byte, this encoding should easily pay for itself in almost all situations.

### Text format

Two new forms of the `import` declaration are added, in addition to the existing one:

```
(import "mod" "foo" ...)                            ;; existing
(import "mod" (item "foo" ...) (item "bar" ...))    ;; compact encoding 1 (new)
(import "mod" (type ... (item "foo") (item "bar"))) ;; compact encoding 2 (new)
```

The `(item)` syntax is used for encoding 2, rather than bare strings, in order to provide room for an identifier, e.g. `(import "mod" (type ... (item $foo "foo")))`.

### Syntax, Validation, Execution

No changes are made to the syntax, validation, or execution sections.


## Alternatives

### Update the AST of modules

It would be possible to manifest these changes in the structure of a WebAssembly module like so:

```
;; Before
import ::== name name externtype
module ::== ... import* ...

;; After
import    ::== name externtype
importmod ::== name import*
module    ::== ... importmod* ...
```

Depending on implementation, this could potentially reduce the size of modules in memory. In addition, the ["read the imports"](https://webassembly.github.io/spec/js-api/#read-the-imports) section of the JS API could be updated to reflect the AST, dispatching only one [[Get]] to the imports object for each `importmod`, resulting in fewer object accesses overall. This could potentially have performance benefits in JS engines.

However, this change to the AST would complicate various aspects of the spec, including some changes to validation and execution, and particularly impacting the `module_imports` function in the Embedding appendix. In addition, it clashes with existing host APIs for imports, particularly the JS API's [Module.imports](https://webassembly.github.io/spec/js-api/index.html#dom-module-imports) function, which returns `{"module": "...", "name": "...", "kind": "..."}` triples. It would presumably be best to change the return value of this function if the structure of imports were to change, but this would be a quite incompatible change.

An experimental specification for this approach can be found on the [ast-update](https://github.com/WebAssembly/compact-import-section/compare/a5f4a85c8...ast-update) branch.

### Add a new section ID

Instead of using an invalid `externtype` to signify a run of compact imports, we could introduce a new section ID to the binary encoding. This would result in a very slightly more compact encoding, but both forms of the import section would need to remain in the spec.

In our opinion, the proposed change is small enough that no new section ID is warranted. Introducing multiple section IDs would complicate toolchains for dubious benefit. Furthermore, the new encoding leaves the door open for future extensions to the import section, such as arbitrary levels of namespacing, by adding more alternatives to the `0x7F` byte.

Consider one example of difficulty caused by a new section id: This proposal suggests that `(import "foo" (item "bar" ...))` should use the compact encoding, and `(import "foo" "bar" ...)` should use the non-compact encoding. Consider, then, this set of imports in the text format:

```
(import "foo" "bar" ...)
(import "baz" (item "im1" ...) (item "im2" ...))
(import "beep" "boop" ...)
```

If the encodings are mixed, but must appear in separate sections, then when round-tripping through the binary format, either it will be impossible to preserve the order of imports (without additional ordering information, which would be superfluous), or the round-trip will be lossy by forcing everything to use the compact encoding. (That said, text tooling may wish to use the compact encoding for everything anyway, as it should be the better choice in the vast majority of cases.)
