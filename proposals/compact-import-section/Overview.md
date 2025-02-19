# Compact import section

## Problem

With js-string-builtins, modules can have a very large amount of imports to handle all the string constants needed in the module. It's possible with future extensions, such as custom-rtts, that we may continue to add special kinds of imports that for modules to use.

The binary format for imports was not designed with these use-cases in mind and every import must redundantly specify both the module specifier and field specifier.

For example, a module that has a 1000 imports from an "env" module will have 1000 copies of the "env" string in the binary.

With a good compression algorithm this could be mitigated on the network, but this cost must still be paid at parsing time after decompression.

In addition to the above, the JS-API specifies an algorithm for 'reading the imports' which suffers from the redundancy in the binary format. For every import we must issue two separate [[Get]] operations. In practice the first one is redundant and could be optimized away. However, [[Get]] is observable to JS code and so special care must be taken to only skip it if nothing could observe it.

## Proposal

This proposal aims to solve the problem by re-using a small subset of the proposed module linking piece of the component-model. The explainer there is worth a read for the rationale behind the design. I will replicate just the pieces needed for a more efficient import format.

### `instancetype`

An `instancetype` is an ordered sequence of `(export <extern>)`. A module can define instance types as part of its type section.

```
type ::=
  func $funcidx |
  ... |
  instance <export>*
export ::=
  (export <extern>)
```

For now we will restrict instance types from being in a recursion group of more than one. This removes the ability to construct mutually recursive instance types, which is unlikely to be needed anytime soon.

No subtyping relation is defined on instance types, and they cannot declare a super type.

### Importing an instance

A new `extern` kind of `instance` is defined.

```
extern ::=
  func $typeidx |
  ...
  instance $typeidx
```

This allows a module to import an instance from somewhere else. The exports of an imported instance are not automatically imported, and an `alias` (see below) statement must be used.

*Note*: This definition implies that an instance type may export another instance type. This is likely okay, but could be restricted if it was a challenge.

### Aliasing the exports of an instance

Once an `instance` has been imported, it's exports must be manually brought into scope using an `alias` statement. The component-model requires this to be done on a per-export basis:

```
(alias (instance $instanceidx) $exportidx)
```

In order to get the maximum reduction in binary size, this proposal instead has a variant `(alias all)` that brings all the exports of an instance into scope:

```
(alias all (instance $instanceidx))
```

### "Read the imports"

An imported instance is handled by the JS-API during "read the imports" by issuing a series of [[Get]] operations to collect all the exports of the imported instance's type.

### Example

Putting it all together we have:

```wasm
(module
  (type (func $f))
  (type
    (instance $Instance
      (export "0" (func $f))
      (export "1" (func $f))
      ..
      (export "10000" (func $f))
    )
  )
  (import
    "env" "instance"
    $instance
    (instance $Instance)
  )
  (alias all (instance $instance))
)
```

```js
// An imported instance is just a JS object with properties, the same as the exports
// object from a wasm instance.
let importedInstance = {
  0: () => {},
  1: () => {},
  ...
  10000: () => {},
};

// Provide the instance as an import.
let instance = await WebAssembly.instantiate(bytecode, {
  env: {
    instance: importedInstance,
  }
});
```

## Binary changes

(TODO)

## One level imports

(TODO)

## Alternatives

Instead of an anticipatory change to the type system to support this use-case, we could consider a strictly binary-only change.

(TODO)
