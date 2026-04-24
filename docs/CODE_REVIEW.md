# Code Review: Structify

## Summary

This document captures findings from a thorough review of the Structify codebase and proposes concrete improvements. Some changes are implemented in this PR; others are recommendations for future work.

## Findings

### 1. Code Duplication in CodeGen Modules (High Impact)

**Status: Partially addressed in this PR**

Every code generator (`Init.hs`, `Cleanup.hs`, `Copy.hs`, `Print.hs`, `Equal.hs`, `Hash.hs`) repeats the same pattern-matching over `EnrichedType` variants (`PrimitiveType`, `PointerType`, `ArrayType`, `StructType`, etc.). This leads to:

- Duplicated format specifier tables (the `"%d"`, `"%zu"`, `"%f"` mapping appears in `Print.hs` twice and partially in `Hash.hs`)
- Duplicated NULL-check patterns (slightly different in each generator)
- Duplicated struct function name construction (`T.toLower name <> "_init"`)

**What this PR does:**
- Implements `CodeGen/Common.hs` with shared utilities: `cFormatSpecifier`, `cTypeDefault`, `cNullCheck`, `cNullCheckVoid`, `structFuncName`, and code-building helpers
- Refactors `Print.hs` to use `cFormatSpecifier` from Common (eliminating two duplicated format tables)
- Adds `structFuncName` helper for conventional naming

**Future work:** Refactor all six generators to use `cBlock`, `cIf`, `cIfNotNull`, `cForLoop` from Common instead of raw `<>` string concatenation. This would make the generated C code structure more apparent in the Haskell source and reduce the risk of mismatched braces or indentation.

### 2. Raw String Concatenation for C Code (Medium Impact)

**Status: Recommendation for future work**

All C code is generated via `Text` concatenation (`<>`) with manually embedded newlines and indentation. For example, in `Cleanup.hs`:

```haskell
"    if (" <> accessor <> " != NULL) {\n" <>
"        for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
"            " <> T.toLower structName <> "_cleanup(&" <> accessor <> "[i]);\n" <>
"        }\n" <>
...
```

This is hard to read, easy to get wrong, and impossible to validate structurally. Consider introducing a lightweight C AST or a `CBuilder` monad that tracks indentation and generates well-formed blocks. The helpers in `CodeGen/Common.hs` are a step in this direction.

### 3. Duplicate Type Definitions (Medium Impact)

**Status: Recommendation for future work**

`FieldAnnotations`, `StructAnnotations`, and `Ownership` are defined in both:
- `Structify.Parser.Attribute` (using `Text` for names)
- `Structify.IR.Types` (using newtype wrappers like `FieldName`, `FunctionName`)

The `Enricher` module manually converts between them field by field. This is fragile -- adding a new annotation field requires updating three places (parser type, IR type, and conversion function).

**Recommendation:** Either:
1. Parameterize the annotation types over the name type (e.g., `FieldAnnotations' nameType`) so both modules share the same shape, or
2. Have the parser produce IR types directly, eliminating the conversion step

### 4. Empty Stub Modules (Low Impact)

**Status: Observation**

13 modules are empty stubs with just `-- TODO: Implement`:
- `Analysis.Validator`, `Analysis.CycleDetector`, `Analysis.ReferenceResolver`, `Analysis.TypeChecker`
- `Transform.Optimizer`, `Transform.Lowering`
- `IR.Builder`, `IR.Enriched`, `IR.CodeGen`
- `CodeGen.Validate`, `CodeGen.Pretty`
- `Error.Reporting`, `Error.Recovery`

These are listed in `structify.cabal` as exposed modules. While having placeholders for planned features is fine, exposing empty modules can confuse users of the library. Consider either:
- Moving them to a `TODO` or `Planned` section in the cabal file with comments
- Adding minimal documentation about what each will do
- Removing them from `exposed-modules` until implemented

### 5. Test Suite Has No Assertions (High Impact)

**Status: Addressed in this PR**

The test suite (`test/Spec.hs`) previously just printed generated code to stdout without any assertions. It was impossible for `cabal test` to catch regressions.

**What this PR does:**
- Rewrites the test suite with a lightweight assertion framework
- Adds 40+ test cases covering:
  - `CodeGen.Common` utility functions
  - Simple struct code generation (all 6 generators)
  - Complex struct code generation (pointers, arrays, nested structs)
  - `no_*` annotation suppression behavior
  - Generated code structural invariants
- Tests exit with a non-zero code on failure

### 6. Unused Imports (Low Impact)

**Status: Addressed in this PR**

Several modules had unused imports that would trigger `-Wunused-imports`:
- `Init.hs`: `Data.Maybe (isJust, fromMaybe)`, `Data.List (intercalate)` -- never used
- `Cleanup.hs`: same unused imports
- `Equal.hs`: `Data.Ord (comparing)` -- never used
- `Structify.hs`: `parseHeaderFromString` imported but unused, `qualified Structify.Parser.C as C` alias unused

### 7. Bug: `unsigned` Format Specifier (Low Impact)

**Status: Fixed in this PR**

In `Print.hs`, `"unsigned"` was mapped to `"%lu"` (unsigned long), but `unsigned` alone in C is equivalent to `unsigned int`, so the correct specifier is `"%u"`. The centralized `cFormatSpecifier` in `Common.hs` now uses the correct `"%u"` mapping.

### 8. `validateAnnotations` Stub (Low Impact)

**Status: Observation**

`Structify.validateAnnotations` is exported from the main module but returns `Left "Validation not yet implemented"`. This could trip up users who expect it to work. It should either be implemented or removed from the export list with a note in the docs.

## Architecture Observations

The overall pipeline design (Parser -> Enricher -> CodeGen) is clean and well-structured. The IR types are well-designed with clear ownership semantics. The code generators produce correct, memory-safe C code.

The main area for improvement is reducing the mechanical duplication across the six code generators, which the `CodeGen/Common.hs` module begins to address.
