# Structify Project Guide for Claude Code

## Project Overview

**Structify** is a Haskell-based code generator that automatically creates C functions (init, cleanup, copy, print, equal, hash) for C structs using inline `__attribute__((structify(...)))` annotations.

**Current Status**: Phase 3 Complete ✓ - All code generators implemented and tested

## Quick Start

```bash
# Enter development environment
nix develop

# Build project
cabal build

# Run tests
cabal test

# Check git status
git status
```

## Project Structure

```
cgen/
├── src/
│   └── Structify/
│       ├── Parser/           # C header parsing (placeholder)
│       │   ├── C.hs         # C type definitions
│       │   └── Attribute.hs # Annotation parsing
│       ├── IR/              # Intermediate representation
│       │   └── Types.hs     # Complete IR type system
│       ├── Transform/       # IR transformations
│       │   └── Enricher.hs  # Parser → IR enrichment
│       └── CodeGen/         # Code generators (COMPLETE ✓)
│           ├── CodeGen.hs   # Unified generator
│           ├── Init.hs      # Init functions
│           ├── Cleanup.hs   # Cleanup functions
│           ├── Copy.hs      # Copy functions
│           ├── Print.hs     # Print functions
│           ├── Equal.hs     # Equality functions
│           └── Hash.hs      # Hash functions
├── test/
│   └── Spec.hs              # Test suite
├── docs/
│   ├── PLAN.md              # Complete implementation plan
│   ├── PHASE3_PROGRESS.md   # Phase 3 completion report
│   └── PROJECT_STATUS.md    # Current project status
└── examples/                # Example C headers
```

## Architecture

### Data Flow Pipeline

```
C Header File
    ↓
Parser (Structify.Parser.C)
    ↓
ParseResult (CStructDecl + attributes)
    ↓
Enricher (Structify.Transform.Enricher)
    ↓
EnrichedStruct (Complete IR)
    ↓
Code Generators (Structify.CodeGen)
    ↓
Generated C Code (init, cleanup, copy, print, equal, hash)
```

### Key Types

**IR Types** (`Structify.IR.Types`):
- `EnrichedStruct` - Complete struct with annotations
- `EnrichedField` - Field with type and annotations
- `EnrichedType` - C type with ownership (Owned/Borrowed/Shared)
- `FieldAnnotations` - 14 field-level annotations
- `StructAnnotations` - 12 struct-level annotations

**Code Generation**:
- `generateAllFunctions :: EnrichedStruct -> GeneratedCode`
- Returns both header declarations and source definitions

## Code Generators (Phase 3 - COMPLETE)

### 1. Init Generator (`Init.hs` - 162 lines)
- NULL safety with errno handling
- Default value initialization
- Pre/post init hooks
- Type-based defaults

### 2. Cleanup Generator (`Cleanup.hs` - 226 lines)
- Ownership-aware memory management
- Dynamic array cleanup
- Recursive cleanup for nested structs
- Pre/post cleanup hooks

### 3. Copy Generator (`Copy.hs` - 300 lines)
- **Deep copy by default for owned pointers**
- Special `char*` string handling (strlen + strcpy)
- Error handling with cleanup-on-failure
- Custom allocators

### 4. Print Generator (`Print.hs` - 264 lines)
- Formatted output with depth limiting (max 10)
- Cycle detection
- NULL-safe printing
- Custom print formats

### 5. Equality Generator (`Equal.hs` - 231 lines)
- Both shallow and deep equality
- **Optimized field ordering** (primitives first)
- Length fields checked before arrays
- No redundant checks

### 6. Hash Generator (`Hash.hs` - 235 lines)
- FNV-1a hash algorithm (64-bit)
- NULL-safe hashing
- Recursive hashing for nested structs

## Important Implementation Details

### Copy Generator
- **Owned pointers are deep-copied by default** (not shallow)
- `char*` strings use `strlen()` and `strcpy()` for proper copying
- Borrowed/shared pointers are shallow-copied
- Error handling uses `goto cleanup` pattern

### Equality Generator
- **Fields sorted by comparison cost** (primitives first for early exit)
- Length fields checked inline with arrays (not as separate fields)
- Deep equality uses recursive calls for struct pointers
- Pattern matching for `PointerType (PointerType (StructType ...))` handles `Person**`

### All Generators
- NULL safety throughout
- Respect all 26 annotations
- Generate both declarations (for .h) and definitions (for .c)

## Testing

Current test (`test/Spec.hs`):
- Creates a `Person` struct with:
  - `char* name` (owned)
  - `int age` (primitive)
  - `Person** children` (owned array with length field)
  - `size_t num_children` (length field)
- Generates all 6 functions
- Verifies output is valid C code

**Test Status**: ✅ All passing

## Common Tasks

### Adding a New Generator Feature

1. Modify the generator in `src/Structify/CodeGen/`
2. Update the unified generator in `CodeGen.hs` if needed
3. Run tests: `cabal test`
4. Check generated output

### Debugging Generated Code

```bash
# Run test and see full output
cabal test 2>&1 | less

# See specific function
cabal test 2>&1 | grep -A 30 "function_name"
```

### Making Changes

1. Edit source files in `src/Structify/`
2. Build: `cabal build`
3. Test: `cabal test`
4. Commit with descriptive message

## Known Issues & TODOs

### Parser (Phase 2 - Incomplete)
- Current parser is a **placeholder**
- Uses simplified type definitions
- Full C parsing deferred (can use language-c library later)

### Remaining Work (Phase 4)
1. CLI implementation
2. Full C parser integration
3. Type checker
4. Reference resolver
5. Validator
6. End-to-end testing

## Annotations Reference

### Field-Level (14)
- `default="value"` - Default initialization
- `length="field"` - Length field for arrays
- `custom_init="func"` - Custom init function
- `custom_cleanup="func"` - Custom cleanup
- `deep_copy` - Enable deep copying
- `no_copy` - Skip in copy
- `no_print` - Skip in print
- `print_format="fmt"` - Custom format
- `no_equal` - Skip in equality
- `no_hash` - Skip in hash
- `custom_hash="func"` - Custom hash
- `owned/borrowed/shared` - Ownership
- `allocator="func"` - Custom allocator
- `deallocator="func"` - Custom deallocator

### Struct-Level (12)
- `pre_init="func"` - Pre-init hook
- `post_init="func"` - Post-init hook
- `pre_cleanup="func"` - Pre-cleanup hook
- `post_cleanup="func"` - Post-cleanup hook
- `no_init` - Don't generate init
- `no_cleanup` - Don't generate cleanup
- `no_copy` - Don't generate copy
- `no_print` - Don't generate print
- `no_equal` - Don't generate equal
- `no_hash` - Don't generate hash
- `print_name="name"` - Custom display name
- `hooks="file"` - Hook definitions

## Performance Optimizations

1. **Equality Field Ordering**
   - Fields sorted by comparison cost
   - Primitives (cost 1) checked first
   - Strings (cost 3) checked second
   - Arrays/structs (cost 5-6) checked last
   - Enables early exit on cheap comparisons

2. **Length Field Optimization**
   - Length checked before array iteration
   - No redundant checks
   - Prevents unnecessary traversal

3. **Deep Copy Optimization**
   - Owned pointers deep-copied by default
   - Efficient string copying
   - Cleanup-on-failure pattern

## Git History

```
98bb156 Complete Phase 3: All code generators implemented and optimized
52bf449 Implement complete IR types and enricher
9c198b4 Add parser layer with type definitions (simplified)
e2605c7 Initial commit: Phase 1 Foundation complete
```

## Build System

- **Nix Flakes**: Reproducible development environment
- **Cabal**: Build system (not Stack)
- **GHC**: 9.6.7
- **Dependencies**: language-c, text, containers, etc.

## Tips for Future Development

1. **Always read files before editing** - Use Read tool first
2. **Test after changes** - Run `cabal test` frequently
3. **Check generated output** - Use grep to inspect specific functions
4. **Follow existing patterns** - All generators follow similar structure
5. **Document changes** - Update progress docs when completing features

## Contact & Resources

- **Documentation**: See `docs/` directory
- **Examples**: See `examples/` directory
- **Tests**: See `test/Spec.hs`

---

**Last Updated**: 2026-03-11
**Phase**: 3 Complete, Ready for Phase 4
