# Structify Development Tasks

## Phase 1: Foundation ✅ COMPLETE

All Phase 1 tasks have been completed successfully.

- [x] Create Nix flake configuration
- [x] Create Cabal package definition
- [x] Create Cabal project file
- [x] Create directory structure
- [x] Create basic module stubs (36 modules)
- [x] Create example C header fixtures
- [x] Test Nix development environment
- [x] Create README and documentation

**Status**: Phase 1 verified complete on 2026-03-11

## Phase 2: IR Construction 🔄 NEXT

### Parser Implementation
- [ ] Implement C header parsing wrapper (Structify.Parser.C)
  - [ ] Integrate language-c library
  - [ ] Handle C preprocessor directives
  - [ ] Extract struct definitions from AST
  - [ ] Handle typedefs and forward declarations

- [ ] Implement attribute parser (Structify.Parser.Attribute)
  - [ ] Parse `__attribute__((structify(...)))` syntax
  - [ ] Extract field-level annotations
  - [ ] Extract struct-level annotations
  - [ ] Validate annotation syntax
  - [ ] Handle malformed attributes gracefully

### IR Types and Construction
- [ ] Complete IR type definitions (Structify.IR.Types)
  - [ ] Define EnrichedType with all C type variants
  - [ ] Define StructHooks for pre/post init/cleanup
  - [ ] Define ValidationRule types
  - [ ] Add source location tracking

- [ ] Implement enricher (Structify.Transform.Enricher)
  - [ ] Merge C AST with parsed attributes
  - [ ] Build EnrichedStruct from C declarations
  - [ ] Resolve type references
  - [ ] Handle nested struct definitions

### Analysis and Validation
- [ ] Implement type checker (Structify.Analysis.TypeChecker)
  - [ ] Validate field types are well-formed
  - [ ] Check pointer ownership annotations
  - [ ] Verify custom function signatures exist

- [ ] Implement reference resolver (Structify.Analysis.ReferenceResolver)
  - [ ] Resolve length="field_name" references
  - [ ] Validate referenced fields exist
  - [ ] Check field types are compatible

- [ ] Implement cycle detector (Structify.Analysis.CycleDetector)
  - [ ] Detect circular struct dependencies
  - [ ] Build dependency graph
  - [ ] Report cycles with clear error messages

- [ ] Implement validator (Structify.Analysis.Validator)
  - [ ] Validate annotation combinations
  - [ ] Check for conflicting annotations
  - [ ] Ensure required annotations present

### Error Handling
- [ ] Enhance error types (Structify.Error.Types)
  - [ ] Define specific error variants
  - [ ] Add source location to errors
  - [ ] Include context information

- [ ] Implement error reporting (Structify.Error.Reporting)
  - [ ] Format errors with source context
  - [ ] Provide helpful suggestions
  - [ ] Support multiple error reporting

## Phase 3: Code Generation 📋 PLANNED

### Core Generators
- [ ] Implement init generator (Structify.CodeGen.Init)
  - [ ] Generate default value initialization
  - [ ] Generate dynamic memory allocation
  - [ ] Add NULL checks and error handling
  - [ ] Integrate pre/post init hooks

- [ ] Implement cleanup generator (Structify.CodeGen.Cleanup)
  - [ ] Generate recursive cleanup for owned pointers
  - [ ] Handle dynamic arrays with length fields
  - [ ] Add NULL safety checks
  - [ ] Integrate pre/post cleanup hooks

- [ ] Implement copy generator (Structify.CodeGen.Copy)
  - [ ] Generate shallow copy logic
  - [ ] Generate deep copy for marked fields
  - [ ] Handle dynamic array copying
  - [ ] Add error handling for allocation failures

### Advanced Generators
- [ ] Implement print generator (Structify.CodeGen.Print)
  - [ ] Generate pretty-print format
  - [ ] Add indentation for nested structs
  - [ ] Implement depth limiting
  - [ ] Add cycle detection
  - [ ] Handle dynamic arrays

- [ ] Implement equality generators (Structify.CodeGen.Equal)
  - [ ] Generate shallow equality function
  - [ ] Generate deep equality function
  - [ ] Handle pointer comparisons
  - [ ] Support selective field comparison

- [ ] Implement hash generator (Structify.CodeGen.Hash)
  - [ ] Implement FNV-1a algorithm
  - [ ] Generate deep hashing logic
  - [ ] Handle recursive struct hashing
  - [ ] Support selective field hashing

### Code Generation Infrastructure
- [ ] Implement common utilities (Structify.CodeGen.Common)
  - [ ] Helper functions for code generation
  - [ ] Type conversion utilities
  - [ ] Name mangling functions

- [ ] Implement pretty printer (Structify.CodeGen.Pretty)
  - [ ] Format generated C code
  - [ ] Add proper indentation
  - [ ] Support different code styles (K&R, Allman, GNU)

## Phase 4: CLI and Testing 🧪 PLANNED

### CLI Implementation
- [ ] Implement CLI options parser (Structify.CLI.Options)
  - [ ] Define command-line arguments
  - [ ] Add help text
  - [ ] Validate option combinations

- [ ] Implement CLI commands (Structify.CLI.Commands)
  - [ ] `generate` command (default)
  - [ ] `validate` command
  - [ ] `analyze` command

- [ ] Implement output formatting (Structify.CLI.Output)
  - [ ] Format success messages
  - [ ] Format error messages
  - [ ] Add progress indicators

### Testing
- [ ] Write parser tests (test/unit/ParserSpec.hs)
  - [ ] Test C struct parsing
  - [ ] Test typedef handling
  - [ ] Test nested struct parsing

- [ ] Write attribute tests (test/unit/AttributeSpec.hs)
  - [ ] Test field-level annotations
  - [ ] Test struct-level annotations
  - [ ] Test malformed attributes

- [ ] Write enricher tests (test/unit/EnricherSpec.hs)
  - [ ] Test AST + annotation merging
  - [ ] Test type resolution
  - [ ] Test error cases

- [ ] Write codegen tests (test/unit/CodeGenSpec.hs)
  - [ ] Test init generation
  - [ ] Test cleanup generation
  - [ ] Test copy generation
  - [ ] Test print generation
  - [ ] Test equality generation
  - [ ] Test hash generation

- [ ] Write validator tests (test/unit/ValidatorSpec.hs)
  - [ ] Test annotation validation
  - [ ] Test reference resolution
  - [ ] Test cycle detection

- [ ] Write end-to-end tests (test/integration/EndToEndSpec.hs)
  - [ ] Test complete workflow
  - [ ] Test generated code compilation
  - [ ] Test generated code execution
  - [ ] Test memory safety (valgrind)

## Phase 5: Polish 🎨 PLANNED

### Documentation
- [ ] Write API documentation
- [ ] Create usage examples
- [ ] Write tutorial
- [ ] Document annotation reference
- [ ] Add troubleshooting guide

### Quality Improvements
- [ ] Improve error messages
- [ ] Add more helpful suggestions
- [ ] Optimize performance
- [ ] Handle edge cases
- [ ] Add more examples

### Additional Features
- [ ] Support union types
- [ ] Support opaque types
- [ ] Support function pointers
- [ ] Add validation function generation
- [ ] Support multiple code styles
- [ ] Generate MSVC compatibility macros

## Current Status Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Foundation | ✅ Complete | 100% |
| Phase 2: IR Construction | 🔄 Next | 0% |
| Phase 3: Code Generation | 📋 Planned | 0% |
| Phase 4: CLI and Testing | 🧪 Planned | 0% |
| Phase 5: Polish | 🎨 Planned | 0% |

**Overall Progress**: 20% (Phase 1 complete)

## Quick Reference

### Development Commands
```bash
# Enter development environment
nix develop

# Build the project
cabal build

# Run tests
cabal test

# Run specific test
cabal test --test-option="-m ParserSpec"

# Install locally
cabal install

# Format code
ormolu -i $(find src -name "*.hs")

# Lint code
hlint src/
```

### File Locations
- Plan: `docs/PLAN.md`
- Tasks: `docs/TASKS.md`
- Examples: `examples/`
- Tests: `test/`
- Source: `src/Structify/`

## Notes

- All module stubs are in place and ready for implementation
- Test infrastructure is set up with Hspec
- Nix environment provides reproducible builds
- C toolchain included for testing generated code
- Example C headers demonstrate expected annotation syntax

---

Last Updated: 2026-03-11
