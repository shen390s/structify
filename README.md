# Structify

Generate initialization, cleanup, deep copy, print, equality, and hash functions for C structs.

## Overview

Structify is a Haskell-based code generator that parses C header files with `__attribute__((structify(...)))` annotations and automatically generates boilerplate functions for managing complex C data structures.

## Features

- **Init functions**: Initialize structs with default values and allocate dynamic memory
- **Cleanup functions**: Recursively free owned memory and call custom cleanup hooks
- **Deep copy functions**: Create deep copies of structs with proper memory allocation
- **Print functions**: Pretty-print structs with indentation, depth limiting, and cycle detection
- **Equality functions**: Both shallow (pointer comparison) and deep (content comparison) equality
- **Hash functions**: FNV-1a hashing with deep hashing of pointed-to data

## Quick Start

### Prerequisites

- Nix with flakes enabled

### Development Environment

```bash
# Enter the Nix development shell
nix develop

# Build the project
cabal build

# Run tests
cabal test

# Install locally
cabal install
```

## Example

### Input C Header (person.h)

```c
typedef struct Person {
    char* name __attribute__((structify(owned, default="NULL")));
    int age __attribute__((structify(default="0")));
    struct Person** children __attribute__((structify(owned, length="num_children", deep_copy)));
    size_t num_children __attribute__((structify(default="0")));
} Person;
```

### Generated Functions

```c
int person_init(Person* self);
void person_cleanup(Person* self);
int person_copy(Person* dest, const Person* src);
void person_print(FILE* stream, const Person* self, int depth);
int person_equal(const Person* a, const Person* b);
int person_deep_equal(const Person* a, const Person* b);
uint64_t person_hash(const Person* self);
```

## Supported Annotations

### Field-level
- `owned` - Field owns memory, will be freed in cleanup
- `borrowed` - Field doesn't own memory
- `default="value"` - Default initialization value
- `length="field"` - For dynamic arrays, specifies length field
- `deep_copy` - Enable deep copy for this field
- `no_print`, `no_equal`, `no_hash` - Skip field in respective functions
- `init="function"`, `cleanup="function"` - Custom init/cleanup functions

### Struct-level
- `pre_init`, `post_init` - Hooks called before/after initialization
- `pre_cleanup`, `post_cleanup` - Hooks called before/after cleanup
- `no_init`, `no_cleanup`, `no_copy`, `no_print`, `no_equal`, `no_hash` - Disable function generation

## Project Status

🚧 **Under Development** - Phase 1 (Foundation) complete

- [x] Nix flake configuration
- [x] Cabal project setup
- [x] Module structure
- [ ] C parser implementation
- [ ] Attribute parser
- [ ] Code generation

## License

MIT

## Contributing

Contributions welcome! Please see the plan file for implementation details.
