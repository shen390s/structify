# Structify

**Automatic C boilerplate generation for structs**

Generate init, cleanup, copy, print, equality, and hash functions for C structs automatically.

[![Status](https://img.shields.io/badge/status-beta-yellow)](https://github.com/yourusername/structify)
[![Phase](https://img.shields.io/badge/phase-4%2F5%20complete-brightgreen)](docs/TASKS.md)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Overview

Structify is a Haskell-based code generator that parses C struct definitions and automatically generates type-safe, memory-safe boilerplate functions. Say goodbye to writing repetitive init, cleanup, and copy functions by hand!

### Features

✅ **Init functions** - Initialize structs with default values and NULL safety
✅ **Cleanup functions** - Recursively free owned memory without leaks
✅ **Deep copy functions** - Create proper deep copies with error handling
✅ **Print functions** - Pretty-print with indentation and cycle detection
✅ **Equality functions** - Both shallow and deep comparison
✅ **Hash functions** - FNV-1a algorithm with deep hashing

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/structify.git
cd structify

# Enter Nix development environment
nix develop

# Build
cabal build

# Install locally (optional)
cabal install
```

### Basic Usage

1. **Create a C header** with your struct:

```c
// person.h
typedef struct Person {
    char* name;
    int age;
    struct Person** children;
    size_t num_children;
} Person;
```

2. **Generate code**:

```bash
structify generate person.h
```

3. **Generated files**:
   - `person_generated.h` - Function declarations
   - `person_generated.c` - Function implementations

4. **Use in your code**:

```c
#include "person_generated.h"

int main() {
    Person p;
    person_init(&p);           // Initialize

    p.name = strdup("Alice");
    p.age = 30;

    person_print(&p, stdout, 0);  // Print to stdout
    person_cleanup(&p);           // Clean up
    return 0;
}
```

## Generated Functions

For each struct, Structify generates:

### 1. Init Function
```c
int person_init(Person* self);
```
- Returns 0 on success, -1 on error (sets errno)
- Initializes all fields to safe defaults
- NULL-safe

### 2. Cleanup Function
```c
void person_cleanup(Person* self);
```
- Recursively frees owned memory
- NULL-safe (safe to call multiple times)
- Handles nested structs and arrays

### 3. Copy Function
```c
int person_copy(Person* dest, const Person* src);
```
- Deep copy by default for owned pointers
- Special handling for strings (strlen + strcpy)
- Error handling with cleanup-on-failure
- Returns 0 on success, -1 on error

### 4. Print Function
```c
void person_print(const Person* self, FILE* out, int depth);
```
- Pretty-printed output with indentation
- Depth limiting (max 10 levels)
- Cycle detection for circular references
- NULL-safe

### 5. Equality Functions
```c
bool person_equal(const Person* a, const Person* b);         // Shallow
bool person_deep_equal(const Person* a, const Person* b);   // Deep
```
- Shallow: pointer address comparison
- Deep: recursive content comparison
- Optimized field ordering (primitives first)
- NULL-safe

### 6. Hash Function
```c
uint64_t person_hash(const Person* self);
```
- FNV-1a algorithm (64-bit)
- Deep hashing of pointed-to data
- Recursive for nested structs
- NULL-safe (returns 0)

## CLI Commands

### Generate
Generate C code from a header file:

```bash
structify generate INPUT [-v] [-H OUTPUT.h] [-C OUTPUT.c]
```

Options:
- `-v, --verbose` - Enable verbose output
- `-H, --output-header FILE` - Specify output header file
- `-C, --output-source FILE` - Specify output source file
- `-o, --only FUNC` - Generate only specific functions

Example:
```bash
structify generate person.h -v
structify generate person.h -H person_api.h -C person_impl.c
structify generate person.h --only init --only cleanup
```

### Validate
Validate annotations without generating code:

```bash
structify validate INPUT
```

### Info
Show information about structs in a header:

```bash
structify info INPUT
```

Example output:
```
Found 1 struct(s):

Struct: Person
  Fields: 4
    name :: char* (Borrowed)
    age :: int
    children :: struct Person* (Borrowed)* (Borrowed)
    num_children :: unsigned
```

## Advanced Features

### Annotations (Coming Soon)

Field-level annotations for fine-grained control:

```c
typedef struct Person {
    char* name __attribute__((structify(owned, default="NULL")));
    int age __attribute__((structify(default="0")));
    struct Person** children __attribute__((structify(owned, length="num_children", deep_copy)));
    size_t num_children __attribute__((structify(default="0")));
} Person __attribute__((structify(pre_init="validate_person")));
```

Supported annotations:
- **Ownership**: `owned`, `borrowed`, `shared`
- **Defaults**: `default="value"`
- **Arrays**: `length="field_name"`
- **Customization**: `custom_init="func"`, `custom_cleanup="func"`
- **Selective generation**: `no_copy`, `no_print`, `no_equal`, `no_hash`
- **Hooks**: `pre_init`, `post_init`, `pre_cleanup`, `post_cleanup`

See [docs/ANNOTATIONS.md](docs/ANNOTATIONS.md) for full reference (coming soon).

## Examples

### Example 1: Simple Point

**Input** (`point.h`):
```c
typedef struct Point {
    int x;
    int y;
} Point;
```

**Usage**:
```c
Point p;
point_init(&p);
p.x = 10;
p.y = 20;
point_print(&p, stdout, 0);  // Prints: Point { x: 10, y: 20 }
```

### Example 2: Linked List Node

**Input**:
```c
typedef struct Node {
    int value;
    struct Node* next;
} Node;
```

**Generated functions handle cycles**:
```c
Node* list = create_cycle();  // Creates circular list
node_print(list, stdout, 0);  // Detects cycle and stops
```

### Example 3: Binary Tree

**Input**:
```c
typedef struct TreeNode {
    int value;
    struct TreeNode* left;
    struct TreeNode* right;
} TreeNode;
```

**Deep copy works recursively**:
```c
TreeNode* original = build_tree();
TreeNode copy;
treenode_copy(&copy, original);  // Deep copies entire tree
```

More examples in [`examples/`](examples/) directory.

## Testing

```bash
# Run all tests
cabal test

# Run specific test suite
cabal test structify-test
cabal test parser-test
cabal test end-to-end-test

# Run with verbose output
cabal test --test-show-details=direct
```

All tests currently passing ✅

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Foundation and build system |
| Phase 2 | ✅ Complete | IR construction and parser |
| Phase 3 | ✅ Complete | All 6 code generators |
| Phase 4 | ✅ Complete | CLI and testing |
| Phase 5 | 🔄 In Progress | Documentation and polish |

**Current version**: Beta (80% complete)

See [docs/TASKS.md](docs/TASKS.md) for detailed progress.

## Architecture

```
C Header File
    ↓
Parser (language-c)
    ↓
Enriched IR (types + annotations)
    ↓
Code Generators (6 generators)
    ↓
Generated C Code (.h + .c)
```

Key modules:
- `Structify.Parser.C` - C header parsing
- `Structify.IR.Types` - Intermediate representation
- `Structify.Transform.Enricher` - AST enrichment
- `Structify.CodeGen.*` - Code generators (Init, Cleanup, Copy, Print, Equal, Hash)
- `Structify.CLI.*` - Command-line interface

See [docs/PLAN.md](docs/PLAN.md) for full architecture.

## Development

### Prerequisites

- Nix with flakes enabled
- GCC or Clang (for testing generated code)

### Building

```bash
nix develop              # Enter development shell
cabal build              # Build project
cabal test               # Run tests
cabal run structify      # Run CLI
```

### Project Structure

```
structify/
├── src/Structify/       # Haskell source code
│   ├── Parser/          # C parsing
│   ├── IR/              # Intermediate representation
│   ├── Transform/       # IR transformations
│   ├── CodeGen/         # Code generators
│   └── CLI/             # Command-line interface
├── test/                # Test suites
├── examples/            # Example C headers
└── docs/                # Documentation
```

## Documentation

- [Implementation Plan](docs/PLAN.md) - Complete architecture and design
- [Task List](docs/TASKS.md) - Development progress
- [Phase 4 Report](docs/PHASE4_COMPLETE.md) - CLI and testing completion
- [Usage Guide](docs/USAGE.md) - Detailed usage examples

## Known Limitations

- Parser uses simplified type handling (full preprocessor support deferred)
- Annotations not yet fully integrated (code generation works with defaults)
- No union support yet
- No validation function generation yet

See [docs/TASKS.md](docs/TASKS.md) for roadmap.

## Contributing

Contributions welcome! Areas that need help:

- [ ] Full preprocessor support in parser
- [ ] Annotation integration
- [ ] Union type support
- [ ] More examples and documentation
- [ ] Performance optimization

Please see [docs/PLAN.md](docs/PLAN.md) for implementation details.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Uses [language-c](https://hackage.haskell.org/package/language-c) for C parsing
- Inspired by Rust's `#[derive]` macros
- Built with Nix for reproducible builds

## Support

- 🐛 [Report issues](https://github.com/yourusername/structify/issues)
- 📖 [Read the docs](docs/)
- 💬 [Discussions](https://github.com/yourusername/structify/discussions)

---

**Status**: Beta - Ready for testing and feedback!

Generated with ❤️ by the Structify team
