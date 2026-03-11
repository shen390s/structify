# Structify Implementation Plan

## Project Overview

**Structify** - A Haskell-based tool that parses C header files and generates initialization, cleanup, and deep copy functions for complex C data structures. Annotations are specified using `__attribute__((structify(...)))` syntax directly in C headers.

## Architecture Summary

### Input/Output Flow
```
C Header (.h) with __attribute__((structify(...))) → Parser → Enriched IR → Code Generator → Generated .c/.h files
```

### Core Components

1. **Parser Layer**
   - Use `language-c` (0.9.4+) for C header parsing (includes attribute parsing)
   - Extract and parse `structify` attributes from AST
   - Integrate C preprocessor support

2. **IR (Intermediate Representation)**
   - Raw C AST (from language-c, includes attributes)
   - Enriched IR (C types + parsed structify attributes)
   - CodeGen IR (optimized for generation)

3. **Code Generation**
   - Use `language-c-quote` for type-safe code generation
   - Generate separate functions per struct: `<struct>_init()`, `<struct>_cleanup()`, `<struct>_copy()`, `<struct>_print()`, `<struct>_equal()`, `<struct>_deep_equal()`, `<struct>_hash()`
   - Return 0 on success, -1 on error (errno style)

4. **Build System**
   - Stack with Cabal file
   - GHC 9.6.4 (LTS 22.9)

## Annotation Syntax

### C Attribute Syntax
Annotations are specified using GCC/Clang `__attribute__` syntax directly in C headers:

```c
// Field-level annotations
struct Example {
    char* name __attribute__((structify(owned, default="NULL")));
    int* data __attribute__((structify(owned, length="count", init="init_data")));
    size_t count __attribute__((structify(default="0")));
    void* opaque __attribute__((structify(borrowed)));
} __attribute__((structify(hooks="example_hooks")));

// Struct-level annotations
struct Person __attribute__((structify(
    pre_init="person_pre_init",
    post_init="person_post_init",
    pre_cleanup="person_pre_cleanup",
    post_cleanup="person_post_cleanup"
))) {
    // fields...
};
```

### Supported Annotations

**Field-level:**
- `owned` - Field owns the memory, will be freed in cleanup
- `borrowed` - Field doesn't own memory, won't be freed
- `shared` - Shared ownership (reference counted, future feature)
- `default="value"` - Default initialization value
- `length="field_name"` - For dynamic arrays, specifies the length field
- `init="function"` - Custom initialization function
- `cleanup="function"` - Custom cleanup function
- `allocator="function"` - Custom allocator (default: malloc)
- `deallocator="function"` - Custom deallocator (default: free)
- `deep_copy` - Enable deep copy for this field
- `no_copy` - Skip this field in copy function
- `no_print` - Skip this field in print function
- `print_format="format"` - Custom printf format for this field
- `no_equal` - Skip this field in equality comparison
- `no_hash` - Skip this field in hash computation
- `hash="function"` - Custom hash function for this field

**Struct-level:**
- `hooks="struct_name"` - Reference to a hooks struct
- `pre_init="function"` - Called before initialization
- `post_init="function"` - Called after initialization
- `pre_cleanup="function"` - Called before cleanup
- `post_cleanup="function"` - Called after cleanup
- `no_init` - Don't generate init function
- `no_cleanup` - Don't generate cleanup function
- `no_copy` - Don't generate copy function
- `no_print` - Don't generate print function
- `no_equal` - Don't generate equality functions
- `no_hash` - Don't generate hash function
- `print_name="custom"` - Custom field name in print output

### Portability Macros
For MSVC compatibility, users can define:

```c
#ifndef __attribute__
#define __attribute__(x)
#endif

#ifndef structify
#define structify(...)
#endif
```

## Module Structure

```
structify/
├── flake.nix                            # Nix flake for dev environment
├── flake.lock                           # Nix flake lock file
├── app/
│   └── Main.hs                          # CLI entry point
├── src/
│   ├── Structify/
│   │   ├── Parser/
│   │   │   ├── C.hs                     # C header parsing wrapper
│   │   │   ├── Attribute.hs             # Parse structify attributes
│   │   │   └── Preprocessor.hs         # C preprocessor integration
│   │   ├── IR/
│   │   │   ├── Types.hs                 # Core IR types
│   │   │   ├── Enriched.hs             # Enriched IR
│   │   │   ├── CodeGen.hs               # CodeGen IR
│   │   │   └── Builder.hs               # Smart constructors
│   │   ├── Analysis/
│   │   │   ├── TypeChecker.hs          # Type validation
│   │   │   ├── ReferenceResolver.hs    # Resolve field references
│   │   │   ├── CycleDetector.hs        # Detect circular deps
│   │   │   └── Validator.hs            # Validation rules
│   │   ├── Transform/
│   │   │   ├── Enricher.hs             # Extract attributes into IR
│   │   │   ├── Optimizer.hs            # IR optimization
│   │   │   └── Lowering.hs             # Lower to CodeGen IR
│   │   ├── CodeGen/
│   │   │   ├── Init.hs                  # Generate init functions
│   │   │   ├── Cleanup.hs              # Generate cleanup functions
│   │   │   ├── Copy.hs                  # Generate copy functions
│   │   │   ├── Print.hs                 # Generate print functions
│   │   │   ├── Equal.hs                 # Generate equality functions
│   │   │   ├── Hash.hs                  # Generate hash functions
│   │   │   ├── Validate.hs             # Generate validation functions
│   │   │   ├── Common.hs                # Shared utilities
│   │   │   └── Pretty.hs                # Pretty printing
│   │   ├── Error/
│   │   │   ├── Types.hs                 # Error types
│   │   │   ├── Reporting.hs            # Error formatting
│   │   │   └── Recovery.hs             # Error recovery
│   │   └── CLI/
│   │       ├── Options.hs               # CLI parsing
│   │       ├── Commands.hs              # CLI commands
│   │       └── Output.hs                # Output formatting
│   └── Structify.hs                     # Main library interface
├── test/
│   ├── unit/
│   │   ├── ParserSpec.hs
│   │   ├── AttributeSpec.hs
│   │   ├── EnricherSpec.hs
│   │   ├── CodeGenSpec.hs
│   │   └── ValidatorSpec.hs
│   ├── integration/
│   │   └── EndToEndSpec.hs
│   └── fixtures/
│       └── headers/                     # Sample annotated C headers
├── examples/
│   ├── simple/
│   │   └── person.h
│   └── complex/
│       └── buffer.h
├── structify.cabal
├── cabal.project                        # Cabal project file
└── README.md
```

## Key Data Types

### Enriched IR
```haskell
data EnrichedIR = EnrichedIR
  { irStructs :: [EnrichedStruct]
  , irTypedefs :: [EnrichedTypedef]
  , irEnums :: [EnrichedEnum]
  , irGlobalConfig :: GlobalConfig
  }

data EnrichedStruct = EnrichedStruct
  { esName :: StructName
  , esFields :: [EnrichedField]
  , esHooks :: StructHooks
  , esSourceLocation :: SrcLoc
  , esOriginalDecl :: CStructDecl
  }

data EnrichedField = EnrichedField
  { efName :: FieldName
  , efType :: EnrichedType
  , efAnnotations :: FieldAnnotations
  , efBitField :: Maybe BitFieldInfo
  , efSourceLocation :: SrcLoc
  }

data EnrichedType
  = PrimitiveType PrimitiveKind
  | PointerType EnrichedType Ownership
  | ArrayType EnrichedType ArraySize
  | StructType StructName
  | EnumType EnumName
  | TypedefType TypedefName
  | FunctionPointerType FunctionSig

data Ownership = Owned | Borrowed | Shared

data FieldAnnotations = FieldAnnotations
  { faDefault :: Maybe DefaultValue
  , faLengthField :: Maybe FieldName
  , faCustomInit :: Maybe FunctionName
  , faCustomCleanup :: Maybe FunctionName
  , faDeepCopy :: Bool
  , faValidation :: Maybe ValidationRule
  , faAllocator :: Maybe FunctionName
  , faDeallocator :: Maybe FunctionName
  }
```

### Code Generation IR
```haskell
data CodeGenIR = CodeGenIR
  { cgFunctions :: [GeneratedFunction]
  , cgIncludes :: [Include]
  , cgForwardDecls :: [ForwardDecl]
  }

data GeneratedFunction
  = InitFunction InitFunctionSpec
  | CleanupFunction CleanupFunctionSpec
  | CopyFunction CopyFunctionSpec
  | PrintFunction PrintFunctionSpec
  | EqualFunction EqualFunctionSpec
  | HashFunction HashFunctionSpec

data InitFunctionSpec = InitFunctionSpec
  { ifsStructName :: StructName
  , ifsParameters :: [Parameter]
  , ifsInitSteps :: [InitStep]
  , ifsErrorHandling :: ErrorHandlingStrategy
  , ifsReturnType :: CType
  }

data InitStep
  = SetDefault FieldName DefaultValue
  | AllocateMemory FieldName AllocSpec
  | CallCustomInit FieldName FunctionName
  | CallHook FunctionName
  | ValidateField FieldName ValidationRule
  | HandleError ErrorCase

data PrintFunctionSpec = PrintFunctionSpec
  { pfsStructName :: StructName
  , pfsParameters :: [Parameter]  -- (FILE* stream, const struct*, int depth, visited set)
  , pfsPrintSteps :: [PrintStep]
  , pfsMaxDepth :: Int
  , pfsReturnType :: CType
  }

data PrintStep
  = PrintStructOpen StructName
  | PrintField FieldName PrintFormat
  | PrintNestedStruct FieldName StructName
  | PrintArray FieldName ArrayPrintSpec
  | PrintStructClose
  | CheckDepthLimit
  | CheckCycle FieldName

data EqualFunctionSpec = EqualFunctionSpec
  { efsStructName :: StructName
  , efsDeep :: Bool  -- True for deep_equal, False for shallow equal
  , efsParameters :: [Parameter]  -- (const struct* a, const struct* b)
  , efsCompareSteps :: [CompareStep]
  , efsReturnType :: CType  -- int (1 for equal, 0 for not equal)
  }

data CompareStep
  = CompareField FieldName CompareStrategy
  | CompareNestedStruct FieldName StructName Bool  -- Bool = deep
  | CompareArray FieldName ArrayCompareSpec
  | ComparePointer FieldName PointerCompareStrategy

data CompareStrategy
  = BitwiseCompare  -- memcmp or ==
  | StringCompare   -- strcmp
  | CustomCompare FunctionName
  | DeepCompare     -- Recursive comparison

data HashFunctionSpec = HashFunctionSpec
  { hfsStructName :: StructName
  , hfsAlgorithm :: HashAlgorithm  -- FNV1a
  , hfsParameters :: [Parameter]  -- (const struct*)
  , hfsHashSteps :: [HashStep]
  , hfsReturnType :: CType  -- size_t or uint64_t
  }

data HashStep
  = HashField FieldName HashStrategy
  | HashNestedStruct FieldName StructName
  | HashArray FieldName ArrayHashSpec
  | CombineHash  -- Combine intermediate hash values

data HashAlgorithm = FNV1a | MurmurHash3 | DJB2 | Custom FunctionName
```

## CLI Interface

```bash
structify [COMMAND] [OPTIONS]

Commands:
  generate    Generate init/cleanup functions (default)
  validate    Validate annotations without generating code
  analyze     Analyze C header and show annotated structures

Options:
  -i, --input FILE       Input C header file (required)
  -o, --output DIR       Output directory (default: current dir)
  --header FILE          Output header file name
  --source FILE          Output source file name
  --prefix PREFIX        Function prefix (default: struct name)
  --style STYLE          Code style: k&r|allman|gnu
  -I, --include DIR      Add include directory for preprocessor
  -D, --define MACRO     Define macro for preprocessor
  --verbose, -v          Verbose output
  --quiet, -q            Suppress non-error output
```

## Implementation Phases

### Phase 1: Foundation
1. Create Nix flake for development environment
2. Initialize Cabal project with module skeleton
3. Setup Cabal dependencies (language-c, language-c-quote, parsec, etc.)
4. Implement C parser wrapper around language-c
5. Implement attribute parser to extract structify annotations
6. Create basic test fixtures with annotated headers

### Phase 2: IR Construction
1. Define core IR data types (IR/Types.hs, IR/Enriched.hs)
2. Implement enricher to extract attributes into IR
3. Implement type checker for validation
4. Implement reference resolver (handle length="field" references)
5. Add comprehensive error reporting

### Phase 3: Code Generation
1. Design CodeGen IR (optimized for generation)
2. Implement init function generator
   - Default value initialization
   - Dynamic memory allocation
   - Error handling with errno
   - Hook integration
3. Implement cleanup function generator
   - Recursive cleanup for owned pointers
   - Custom deallocator support
   - NULL safety checks
4. Implement deep copy generator
5. Implement print function generator
   - Pretty format output to FILE* stream
   - Recursive printing with indentation
   - Array contents printing (using length field)
   - Depth limiting (default max depth: 10)
   - Cycle detection for circular references
6. Implement equality function generators
   - Shallow equality (pointer address comparison)
   - Deep equality (recursive content comparison)
   - Support for no_equal attribute
7. Implement hash function generator
   - FNV-1a algorithm
   - Deep hashing (hash pointed-to data)
   - Recursive hashing for nested structs
   - Selective field hashing (no_hash attribute)
   - Custom hash functions per field

### Phase 4: CLI and Testing
1. Implement CLI using optparse-applicative
2. Add commands: generate, validate, analyze
3. Write unit tests (Hspec)
4. Write integration tests (end-to-end)
5. Create example projects with annotated headers

### Phase 5: Polish
1. Error message improvements
2. Documentation (README, examples, API docs)
3. Performance optimization
4. Edge case handling

## Generated Code Example

### Input C Header (person.h)
```c
typedef struct Person {
    char* name __attribute__((structify(owned, default="NULL")));
    int age __attribute__((structify(default="0")));
    struct Person** children __attribute__((structify(owned, length="num_children", deep_copy)));
    size_t num_children __attribute__((structify(default="0")));
} Person;
```

### Generated Output (person_gen.h)
```c
#ifndef PERSON_GEN_H
#define PERSON_GEN_H

#include "person.h"
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

int person_init(Person* self);
void person_cleanup(Person* self);
int person_copy(Person* dest, const Person* src);
void person_print(FILE* stream, const Person* self, int depth);
int person_equal(const Person* a, const Person* b);
int person_deep_equal(const Person* a, const Person* b);
uint64_t person_hash(const Person* self);

#endif
```

### Generated Output (person_gen.c)
```c
#include "person_gen.h"
#include <stdlib.h>
#include <string.h>

int person_init(Person* self) {
    if (self == NULL) {
        errno = EINVAL;
        return -1;
    }

    self->name = NULL;
    self->age = 0;
    self->children = NULL;
    self->num_children = 0;

    return 0;
}

void person_cleanup(Person* self) {
    if (self == NULL) return;

    if (self->name != NULL) {
        free(self->name);
        self->name = NULL;
    }

    if (self->children != NULL) {
        for (size_t i = 0; i < self->num_children; i++) {
            if (self->children[i] != NULL) {
                person_cleanup(self->children[i]);
                free(self->children[i]);
            }
        }
        free(self->children);
        self->children = NULL;
    }

    self->num_children = 0;
}

int person_copy(Person* dest, const Person* src) {
    if (dest == NULL || src == NULL) {
        errno = EINVAL;
        return -1;
    }

    if (person_init(dest) != 0) return -1;

    if (src->name != NULL) {
        dest->name = strdup(src->name);
        if (dest->name == NULL) {
            person_cleanup(dest);
            errno = ENOMEM;
            return -1;
        }
    }

    dest->age = src->age;

    if (src->children != NULL && src->num_children > 0) {
        dest->children = calloc(src->num_children, sizeof(Person*));
        if (dest->children == NULL) {
            person_cleanup(dest);
            errno = ENOMEM;
            return -1;
        }

        dest->num_children = src->num_children;

        for (size_t i = 0; i < src->num_children; i++) {
            if (src->children[i] != NULL) {
                dest->children[i] = malloc(sizeof(Person));
                if (dest->children[i] == NULL) {
                    person_cleanup(dest);
                    errno = ENOMEM;
                    return -1;
                }
                if (person_copy(dest->children[i], src->children[i]) != 0) {
                    person_cleanup(dest);
                    return -1;
                }
            }
        }
    }

    return 0;
}
```

### Generated Print Function (person_gen.c continued)
```c
// Internal helper for cycle detection
typedef struct VisitedNode {
    const void* ptr;
    struct VisitedNode* next;
} VisitedNode;

static int is_visited(VisitedNode* visited, const void* ptr) {
    while (visited != NULL) {
        if (visited->ptr == ptr) return 1;
        visited = visited->next;
    }
    return 0;
}

static void print_indent(FILE* stream, int depth) {
    for (int i = 0; i < depth; i++) {
        fprintf(stream, "  ");
    }
}

void person_print(FILE* stream, const Person* self, int depth) {
    if (stream == NULL || self == NULL) return;

    // Depth limit check
    if (depth > 10) {
        fprintf(stream, "...(max depth)");
        return;
    }

    fprintf(stream, "Person {\n");

    // Print name field
    print_indent(stream, depth + 1);
    fprintf(stream, "name: ");
    if (self->name != NULL) {
        fprintf(stream, "\"%s\",\n", self->name);
    } else {
        fprintf(stream, "NULL,\n");
    }

    // Print age field
    print_indent(stream, depth + 1);
    fprintf(stream, "age: %d,\n", self->age);

    // Print children array
    print_indent(stream, depth + 1);
    fprintf(stream, "children: ");
    if (self->children != NULL && self->num_children > 0) {
        fprintf(stream, "[\n");
        for (size_t i = 0; i < self->num_children; i++) {
            print_indent(stream, depth + 2);
            if (self->children[i] != NULL) {
                person_print(stream, self->children[i], depth + 2);
            } else {
                fprintf(stream, "NULL");
            }
            if (i < self->num_children - 1) {
                fprintf(stream, ",");
            }
            fprintf(stream, "\n");
        }
        print_indent(stream, depth + 1);
        fprintf(stream, "],\n");
    } else {
        fprintf(stream, "NULL,\n");
    }

    // Print num_children field
    print_indent(stream, depth + 1);
    fprintf(stream, "num_children: %zu\n", self->num_children);

    print_indent(stream, depth);
    fprintf(stream, "}");
}
```

### Example Usage
```c
#include "person_gen.h"

int main() {
    Person p;
    person_init(&p);

    p.name = strdup("Alice");
    p.age = 30;

    // Print to stdout
    person_print(stdout, &p, 0);
    fprintf(stdout, "\n");

    person_cleanup(&p);
    return 0;
}

// Output:
// Person {
//   name: "Alice",
//   age: 30,
//   children: NULL,
//   num_children: 0
// }
```

### Generated Equality Functions (person_gen.c continued)
```c
// Shallow equality: compare pointers by address
int person_equal(const Person* a, const Person* b) {
    if (a == b) return 1;  // Same pointer or both NULL
    if (a == NULL || b == NULL) return 0;

    // Compare name pointers (shallow)
    if (a->name != b->name) return 0;

    // Compare age
    if (a->age != b->age) return 0;

    // Compare children pointer (shallow)
    if (a->children != b->children) return 0;

    // Compare num_children
    if (a->num_children != b->num_children) return 0;

    return 1;
}

// Deep equality: recursively compare pointed-to data
int person_deep_equal(const Person* a, const Person* b) {
    if (a == b) return 1;  // Same pointer or both NULL
    if (a == NULL || b == NULL) return 0;

    // Deep compare name strings
    if (a->name != b->name) {
        if (a->name == NULL || b->name == NULL) return 0;
        if (strcmp(a->name, b->name) != 0) return 0;
    }

    // Compare age
    if (a->age != b->age) return 0;

    // Compare num_children first
    if (a->num_children != b->num_children) return 0;

    // Deep compare children array
    if (a->children != b->children) {
        if (a->children == NULL || b->children == NULL) return 0;
        for (size_t i = 0; i < a->num_children; i++) {
            if (!person_deep_equal(a->children[i], b->children[i])) {
                return 0;
            }
        }
    }

    return 1;
}
```

### Generated Hash Function (person_gen.c continued)
```c
// FNV-1a hash constants
#define FNV_OFFSET_BASIS 14695981039346656037ULL
#define FNV_PRIME 1099511628211ULL

static uint64_t fnv1a_hash_bytes(const void* data, size_t len, uint64_t hash) {
    const uint8_t* bytes = (const uint8_t*)data;
    for (size_t i = 0; i < len; i++) {
        hash ^= bytes[i];
        hash *= FNV_PRIME;
    }
    return hash;
}

uint64_t person_hash(const Person* self) {
    if (self == NULL) return 0;

    uint64_t hash = FNV_OFFSET_BASIS;

    // Hash name string (deep)
    if (self->name != NULL) {
        hash = fnv1a_hash_bytes(self->name, strlen(self->name), hash);
    }

    // Hash age
    hash = fnv1a_hash_bytes(&self->age, sizeof(self->age), hash);

    // Hash children array (deep, recursive)
    if (self->children != NULL) {
        for (size_t i = 0; i < self->num_children; i++) {
            if (self->children[i] != NULL) {
                uint64_t child_hash = person_hash(self->children[i]);
                hash = fnv1a_hash_bytes(&child_hash, sizeof(child_hash), hash);
            }
        }
    }

    // Hash num_children
    hash = fnv1a_hash_bytes(&self->num_children, sizeof(self->num_children), hash);

    return hash;
}
```

### Example Usage
```c
#include "person_gen.h"

int main() {
    Person p1, p2;
    person_init(&p1);
    person_init(&p2);

    p1.name = strdup("Alice");
    p1.age = 30;

    p2.name = strdup("Alice");
    p2.age = 30;

    // Shallow equality: false (different string pointers)
    printf("Shallow equal: %d\n", person_equal(&p1, &p2));  // 0

    // Deep equality: true (same string content)
    printf("Deep equal: %d\n", person_deep_equal(&p1, &p2));  // 1

    // Hash values
    printf("Hash p1: %lu\n", person_hash(&p1));
    printf("Hash p2: %lu\n", person_hash(&p2));  // Same as p1

    person_cleanup(&p1);
    person_cleanup(&p2);
    return 0;
}
```

## Dependencies (Cabal)

```cabal
build-depends:
  base >= 4.17 && < 5,
  language-c >= 0.9.4,
  language-c-quote >= 0.13,
  parsec >= 3.1,
  text >= 2.0,
  bytestring >= 0.11,
  containers >= 0.6,
  mtl >= 2.3,
  transformers >= 0.6,
  filepath >= 1.4,
  directory >= 1.3,
  optparse-applicative >= 0.18,
  pretty-simple >= 4.1
```

## Key Design Decisions

### 1. C Attributes for Inline Annotations
**Decision**: Use `__attribute__((structify(...)))` syntax

**Rationale**:
- Single source of truth (annotations with code)
- Native C syntax (GCC/Clang)
- Inline with field definitions (easy to maintain)
- Type-checked by compiler
- Most elegant integration
- Tool name in attribute makes it clear and avoids conflicts

**Tradeoffs**:
- Compiler-specific (GCC/Clang, not MSVC without macros)
- Requires modifying C headers
- Limited to what attribute syntax supports

**Mitigation**:
- Provide compatibility macros for MSVC
- Document macro approach for portability
- Keep attribute syntax simple and parseable

### 2. Haskell as Implementation Language
**Decision**: Use Haskell (user requirement)

**Benefits**:
- Strong type system catches errors early
- Excellent parsing libraries (language-c)
- Type-safe code generation (language-c-quote)
- Pure functions make testing easier
- ADTs naturally model IR

### 3. Three-Layer IR
**Decision**: Use Raw C AST → Enriched IR → CodeGen IR

**Rationale**:
- Separation of concerns (parsing vs generation)
- Each layer optimized for its purpose
- Easier to test and maintain
- Allows optimization passes between layers

### 4. Error Handling in Generated Code
**Decision**: Return 0 on success, -1 on error (errno style)

**Rationale**:
- Standard C convention
- Consistent with stdlib (malloc, etc.)
- Simple to use
- Composable (can check return values easily)

## Features Supported in v1

### Must Have
- Parse C structs with nested types
- Parse __attribute__((structify(...))) annotations
- Handle dynamic arrays (with length="field" annotation)
- Generate init functions with default values
- Generate cleanup functions with recursive free
- Generate deep copy functions
- Generate print functions with pretty format
  - Recursive printing of nested structs
  - Array contents printing
  - Depth limiting (configurable, default 10)
  - Cycle detection for circular references
- Generate equality functions
  - Shallow equality (pointer address comparison)
  - Deep equality (recursive content comparison)
  - Selective field comparison (no_equal attribute)
- Generate hash functions
  - FNV-1a algorithm
  - Deep hashing of pointed-to data
  - Recursive hashing for nested structs
  - Selective field hashing (no_hash attribute)
- Support custom init/cleanup hooks
- Basic error handling (NULL checks, allocation failures)
- Bit field support
- Ownership tracking (owned/borrowed)
- Nix flake for reproducible development environment

### Nice to Have (Future)
- Union support
- Opaque type handling
- Function pointer initialization
- Custom allocators per field
- Validation function generation
- Multiple code style options
- MSVC compatibility macros generation
- Shared ownership (reference counting)
- Multiple print formats (JSON, S-expression)
- Print to string buffer option
- Custom print formatters per field type
- Alternative hash algorithms (MurmurHash3, djb2)
- Hash to string buffer option
- Cached hash values (memoization)

## Testing Strategy

### Unit Tests
- Parser: various C constructs with attributes
- Attribute parser: structify annotation extraction
- Enricher: attribute extraction into IR
- TypeChecker: type validation
- CodeGen: generated code structure
  - Init function generation
  - Cleanup function generation
  - Copy function generation
  - Print function generation (with depth/cycle tests)
  - Equality function generation (shallow vs deep)
  - Hash function generation (consistency, distribution)

### Integration Tests
- End-to-end: annotated header → generated code
- Compilation: generated code compiles with GCC/Clang
- Runtime: generated functions work correctly
  - Init/cleanup round-trip
  - Deep copy correctness
  - Print output format validation
  - Circular reference handling in print
  - Equality: shallow vs deep comparison correctness
  - Hash: consistency (equal objects have equal hashes)
  - Hash: distribution (different objects likely have different hashes)
- Memory: no leaks (valgrind)
- Portability: test with MSVC compatibility macros

### Property Tests (QuickCheck)
- Init always returns valid state or error
- Cleanup never leaks memory
- Round-trip: init → cleanup → init
- Equality reflexivity: x == x
- Equality symmetry: x == y ⟹ y == x
- Equality transitivity: x == y ∧ y == z ⟹ x == z
- Hash consistency: x == y ⟹ hash(x) == hash(y)
- Deep copy equality: deep_equal(x, copy(x))

## Development Environment

### Nix Flake Configuration
The project uses Nix flakes for reproducible development environment:

```nix
{
  description = "Structify - Generate init/cleanup functions for C structs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haskellPackages = pkgs.haskell.packages.ghc964;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Haskell toolchain
            haskellPackages.ghc
            haskellPackages.cabal-install
            haskellPackages.haskell-language-server
            haskellPackages.hlint
            haskellPackages.ormolu

            # C toolchain (for testing generated code)
            gcc
            clang
            valgrind

            # Development tools
            git
            zlib
          ];

          shellHook = ''
            echo "Structify development environment"
            echo "GHC version: $(ghc --version)"
            echo "Cabal version: $(cabal --version | head -n1)"
          '';
        };

        packages.default = haskellPackages.callCabal2nix "structify" ./. {};
      }
    );
}
```

### Usage
```bash
# Enter development environment
nix develop

# Build the project
cabal build

# Run tests
cabal test

# Install locally
cabal install
```

## Critical Files to Create

1. `/home/rshen/works/projects/cgen/flake.nix` - Nix flake configuration
2. `/home/rshen/works/projects/cgen/structify.cabal` - Package definition
3. `/home/rshen/works/projects/cgen/cabal.project` - Cabal project config
4. `/home/rshen/works/projects/cgen/src/Structify/Parser/C.hs` - Core C parsing
5. `/home/rshen/works/projects/cgen/src/Structify/Parser/Attribute.hs` - Attribute parsing
6. `/home/rshen/works/projects/cgen/src/Structify/IR/Types.hs` - Core IR types
7. `/home/rshen/works/projects/cgen/src/Structify/Transform/Enricher.hs` - Extract attributes to IR
8. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Init.hs` - Init generation
9. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Cleanup.hs` - Cleanup generation
10. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Copy.hs` - Copy generation
11. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Print.hs` - Print generation
12. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Equal.hs` - Equality generation
13. `/home/rshen/works/projects/cgen/src/Structify/CodeGen/Hash.hs` - Hash generation
14. `/home/rshen/works/projects/cgen/app/Main.hs` - CLI entry point

## Build System Choice

**Decision**: Use Cabal with Nix flakes (not Stack)

**Rationale**:
- Nix provides reproducible builds across machines
- Cabal is more lightweight and flexible
- Better integration with Nix ecosystem
- Easier to specify exact GHC and dependency versions
- Stack adds unnecessary complexity for this project

## Next Steps

1. Review and approve this plan
2. Begin Phase 1: Foundation
   - Create Nix flake configuration
   - Initialize Cabal project
   - Setup dependencies
   - Implement basic parsers
3. Create example fixtures for testing
4. Iterate on design based on real-world testing
