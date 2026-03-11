# Structify - Remaining Tasks

**Current Status**: Phase 3 Complete ✓
**Next Phase**: Phase 4 - Integration & CLI

## Phase 4: Integration & CLI

### 4.1 CLI Implementation (High Priority)

#### 4.1.1 Command-Line Interface
- [ ] Implement `Structify.CLI.Options` module
  - [ ] Define command-line options (input file, output file, flags)
  - [ ] Add `--only` flag to generate specific functions
  - [ ] Add `--validate` flag for validation only
  - [ ] Add `--verbose` flag for detailed output
  - [ ] Add `--help` and `--version` flags

- [ ] Implement `Structify.CLI.Commands` module
  - [ ] `generate` command - Generate C code from header
  - [ ] `validate` command - Validate annotations only
  - [ ] `info` command - Show struct information

- [ ] Implement `Structify.CLI.Output` module
  - [ ] Format error messages
  - [ ] Format success messages
  - [ ] Progress indicators
  - [ ] Color output support (optional)

- [ ] Update `app/Main.hs`
  - [ ] Parse command-line arguments
  - [ ] Route to appropriate command
  - [ ] Handle errors gracefully
  - [ ] Exit with proper status codes

#### 4.1.2 File I/O
- [ ] Implement header file reading
- [ ] Implement generated code writing
  - [ ] Write header declarations (.h file)
  - [ ] Write source definitions (.c file)
  - [ ] Handle file permissions
  - [ ] Backup existing files (optional)

#### 4.1.3 Error Reporting
- [ ] Implement `Structify.Error.Reporting` module
  - [ ] Format parse errors with line numbers
  - [ ] Format validation errors
  - [ ] Format generation errors
  - [ ] Pretty-print error messages

- [ ] Implement `Structify.Error.Recovery` module
  - [ ] Error recovery strategies
  - [ ] Partial code generation on errors
  - [ ] Suggestions for fixing errors

### 4.2 Parser Integration (Medium Priority)

#### 4.2.1 Full C Parser
- [ ] Implement complete C header parsing
  - [ ] Use language-c library properly
  - [ ] Parse struct declarations
  - [ ] Parse typedef declarations
  - [ ] Parse forward declarations
  - [ ] Handle preprocessor directives

- [ ] Implement `Structify.Parser.Preprocessor` module
  - [ ] Handle #include directives
  - [ ] Handle #define macros
  - [ ] Handle conditional compilation

- [ ] Extract GCC attributes
  - [ ] Parse `__attribute__((structify(...)))`
  - [ ] Extract annotation key-value pairs
  - [ ] Handle malformed attributes gracefully

#### 4.2.2 Attribute Parsing
- [ ] Complete `Structify.Parser.Attribute` module
  - [ ] Parse all 14 field-level annotations
  - [ ] Parse all 12 struct-level annotations
  - [ ] Validate annotation syntax
  - [ ] Report annotation errors with locations

### 4.3 Validation Layer (Medium Priority)

#### 4.3.1 Type Checker
- [ ] Implement `Structify.Analysis.TypeChecker` module
  - [ ] Validate field types are well-formed
  - [ ] Check pointer ownership annotations
  - [ ] Verify custom function signatures exist
  - [ ] Check for circular dependencies

#### 4.3.2 Reference Resolver
- [ ] Implement `Structify.Analysis.ReferenceResolver` module
  - [ ] Resolve `length="field_name"` references
  - [ ] Validate referenced fields exist
  - [ ] Check field types are compatible (length must be numeric)
  - [ ] Resolve custom function references

#### 4.3.3 Cycle Detector
- [ ] Implement `Structify.Analysis.CycleDetector` module
  - [ ] Detect circular struct dependencies
  - [ ] Warn about potential infinite recursion
  - [ ] Suggest fixes for cycles

#### 4.3.4 Validator
- [ ] Implement `Structify.Analysis.Validator` module
  - [ ] Validate annotation combinations
  - [ ] Check for conflicting annotations
  - [ ] Ensure required annotations present
  - [ ] Validate ownership semantics

### 4.4 Code Generation Improvements (Low Priority)

#### 4.4.1 Code Formatting
- [ ] Implement `Structify.CodeGen.Pretty` module
  - [ ] Format generated C code nicely
  - [ ] Add proper indentation
  - [ ] Add blank lines between functions
  - [ ] Add comments for generated code

#### 4.4.2 Code Validation
- [ ] Implement `Structify.CodeGen.Validate` module
  - [ ] Validate generated C code syntax
  - [ ] Check for common C errors
  - [ ] Verify function signatures match

#### 4.4.3 Additional Generators (Optional)
- [ ] Implement serialization functions (to JSON/binary)
- [ ] Implement deserialization functions
- [ ] Implement comparison functions (less than, greater than)
- [ ] Implement clone functions (allocate + copy)

### 4.5 Testing (High Priority)

#### 4.5.1 Unit Tests
- [ ] Test each code generator individually
  - [ ] Test init generator with various types
  - [ ] Test cleanup generator with ownership
  - [ ] Test copy generator with deep/shallow
  - [ ] Test print generator with cycles
  - [ ] Test equal generator with arrays
  - [ ] Test hash generator with collisions

- [ ] Test parser with real C headers
- [ ] Test enricher with various annotations
- [ ] Test validators with invalid input

#### 4.5.2 Integration Tests
- [ ] Test end-to-end code generation
  - [ ] Parse real C header
  - [ ] Generate all functions
  - [ ] Compile generated C code with GCC
  - [ ] Run generated code
  - [ ] Verify correctness

- [ ] Test with example headers
  - [ ] `examples/simple/person.h`
  - [ ] `examples/complex/buffer.h`
  - [ ] Create more examples

#### 4.5.3 Property-Based Tests
- [ ] Use QuickCheck for property testing
  - [ ] Generated init + cleanup should not leak
  - [ ] Copy + equal should be identity
  - [ ] Hash should be consistent
  - [ ] Deep equal should be transitive

### 4.6 Documentation (Medium Priority)

#### 4.6.1 User Documentation
- [ ] Write user guide
  - [ ] Installation instructions
  - [ ] Quick start tutorial
  - [ ] Annotation reference
  - [ ] Examples and recipes
  - [ ] Troubleshooting guide

- [ ] Write API documentation
  - [ ] Haddock comments for all modules
  - [ ] Generate HTML documentation
  - [ ] Publish to GitHub Pages

#### 4.6.2 Developer Documentation
- [ ] Architecture documentation
- [ ] Contributing guide
- [ ] Code style guide
- [ ] Testing guide

### 4.7 Build & Distribution (Low Priority)

#### 4.7.1 Build System
- [ ] Optimize build configuration
- [ ] Add build profiles (dev, release)
- [ ] Configure warnings and optimizations
- [ ] Set up CI/CD (GitHub Actions)

#### 4.7.2 Distribution
- [ ] Create release builds
- [ ] Package for Nix
- [ ] Package for Cabal/Hackage
- [ ] Create Docker image (optional)
- [ ] Create binary releases

### 4.8 Performance & Optimization (Low Priority)

#### 4.8.1 Performance Testing
- [ ] Benchmark code generation speed
- [ ] Profile memory usage
- [ ] Test with large headers (1000+ structs)
- [ ] Optimize hot paths

#### 4.8.2 Code Quality
- [ ] Run hlint and fix warnings
- [ ] Run ormolu for formatting
- [ ] Add pre-commit hooks
- [ ] Set up code coverage

## Phase 5: Advanced Features (Future)

### 5.1 Advanced Code Generation
- [ ] Generate thread-safe versions (with mutexes)
- [ ] Generate async versions (with callbacks)
- [ ] Generate reference-counted versions
- [ ] Generate arena allocator versions

### 5.2 Language Support
- [ ] Generate C++ wrappers
- [ ] Generate Rust FFI bindings
- [ ] Generate Python bindings (ctypes)
- [ ] Generate Go bindings (cgo)

### 5.3 IDE Integration
- [ ] Language Server Protocol (LSP) support
- [ ] Syntax highlighting for annotations
- [ ] Auto-completion for annotations
- [ ] Inline error reporting

### 5.4 Advanced Features
- [ ] Watch mode (regenerate on file change)
- [ ] Incremental generation
- [ ] Parallel code generation
- [ ] Custom code templates

## Priority Summary

### Must Have (Phase 4)
1. ✅ Code generators (DONE)
2. CLI implementation
3. File I/O
4. Basic error reporting
5. Integration tests
6. User documentation

### Should Have
1. Full C parser
2. Validation layer
3. Unit tests
4. Property-based tests
5. Code formatting

### Nice to Have
1. Advanced error recovery
2. Performance optimizations
3. Additional generators
4. CI/CD setup

### Future
1. Advanced features (Phase 5)
2. Language bindings
3. IDE integration

## Estimated Effort

- **Phase 4 Core** (CLI + Integration): 2-3 weeks
- **Phase 4 Complete** (with tests): 4-6 weeks
- **Phase 5** (Advanced features): 2-4 months

## Next Immediate Steps

1. **Start CLI implementation** - Create basic command-line interface
2. **Implement file I/O** - Read headers, write generated code
3. **Create integration test** - End-to-end test with real C header
4. **Write user guide** - Document how to use the tool

---

**Last Updated**: 2026-03-11
**Current Phase**: 3 Complete, Starting Phase 4
