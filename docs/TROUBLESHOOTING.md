# Structify Troubleshooting Guide

**Solutions to common problems**

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Parse Errors](#parse-errors)
3. [Compilation Errors](#compilation-errors)
4. [Runtime Issues](#runtime-issues)
5. [Generated Code Problems](#generated-code-problems)
6. [Performance Issues](#performance-issues)

---

## Installation Issues

### Problem: Nix not found

```
bash: nix: command not found
```

**Solution**:

Install Nix with flakes enabled:

```bash
# Install Nix (official installer)
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Restart your shell after installation.

### Problem: Flakes not enabled

```
error: experimental Nix feature 'flakes' is disabled
```

**Solution**:

```bash
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Problem: cabal command not found

```
bash: cabal: command not found
```

**Solution**:

You need to be in the Nix development shell:

```bash
nix develop
```

All commands (`cabal`, `ghc`, `gcc`) are available inside the shell.

### Problem: Build fails with missing dependencies

```
Error: Some packages are missing
```

**Solution**:

Clean and rebuild:

```bash
cabal clean
cabal update
cabal build
```

If still failing, try:

```bash
nix develop --command cabal build --enable-tests
```

---

## Parse Errors

### Problem: Preprocessor directives not supported

```
Error: Parse error: Lexical error! The character '#' does not fit here.
```

**Solution**:

Structify's parser has limited preprocessor support. Options:

**Option 1**: Remove preprocessor directives:

❌ **This won't work**:
```c
#ifndef PERSON_H
#define PERSON_H

typedef struct Person {
    char* name;
} Person;

#endif
```

✅ **This will work**:
```c
typedef struct Person {
    char* name;
} Person;
```

**Option 2**: Preprocess first (future):

```bash
gcc -E person.h -o person_preprocessed.h
structify generate person_preprocessed.h
```

### Problem: Comments cause parse errors

```
Error: Syntax Error! The symbol '/' does not fit here.
```

**Solution**:

Remove comments from your header before generating:

❌ **This may fail**:
```c
// This is a person struct
typedef struct Person {
    char* name;  // Person's name
} Person;
```

✅ **This will work**:
```c
typedef struct Person {
    char* name;
} Person;
```

Or use the parser without preprocessing:

```bash
structify generate person.h
```

### Problem: Complex types not recognized

```
Error: Unknown type 'custom_t'
```

**Solution**:

Ensure all types are either:
1. Built-in C types (`int`, `char*`, etc.)
2. Defined in the same file
3. Standard types (`size_t`, `uint64_t`, etc.)

❌ **This may fail**:
```c
#include "custom.h"  // External type
typedef struct {
    custom_t data;  // Unknown to parser
} Container;
```

✅ **This will work**:
```c
typedef struct {
    int data;
} Container;
```

---

## Compilation Errors

### Problem: Missing includes in generated code

```
error: implicit declaration of function 'strlen'
```

**Solution**:

The generated source file includes standard headers. If still missing, add to your test file:

```c
#include <string.h>
#include <stdlib.h>
#include "person_generated.h"
```

### Problem: Format string warnings

```
warning: format '%d' expects argument of type 'int', but argument has type 'long unsigned int'
```

**Solution**:

This is usually safe to ignore, but if it bothers you:

1. Use specific types (`uint32_t` instead of `unsigned long`)
2. Or ignore the warning: `gcc -Wno-format ...`

The print generators try to use correct formats but may not catch all cases.

### Problem: Undefined reference to generated functions

```
undefined reference to `person_init'
```

**Solution**:

Make sure to link the generated `.c` file:

```bash
gcc -o test test.c person_generated.c -I.
```

Not just:
```bash
gcc -o test test.c  # Missing generated.c!
```

### Problem: Multiple definition errors

```
multiple definition of `person_init'
```

**Solution**:

Don't include the `.c` file directly:

❌ **Wrong**:
```c
#include "person_generated.c"  // Don't do this!
```

✅ **Correct**:
```c
#include "person_generated.h"
```

Then link at compile time:
```bash
gcc test.c person_generated.c
```

---

## Runtime Issues

### Problem: Segmentation fault on init

```
Segmentation fault (core dumped)
```

**Solution**:

Make sure to pass a valid pointer:

❌ **Wrong**:
```c
Person* p = NULL;
person_init(p);  // CRASH! NULL pointer
```

✅ **Correct**:
```c
Person p;  // On stack
person_init(&p);

// Or on heap:
Person* p = malloc(sizeof(Person));
person_init(p);
```

### Problem: Double free detected

```
double free or corruption
```

**Solution**:

Don't call cleanup twice on the same struct:

❌ **Wrong**:
```c
person_cleanup(&p);
person_cleanup(&p);  // ERROR: Double free!
```

✅ **Correct**:
```c
person_cleanup(&p);
// Don't cleanup again
```

Or check before cleanup:
```c
if (p.name != NULL) {
    person_cleanup(&p);
}
```

### Problem: Memory leak

```
definitely lost: 1,024 bytes in 1 blocks
```

**Solution**:

Remember that borrowed pointers aren't freed automatically:

❌ **Leaks**:
```c
Person p;
person_init(&p);
p.name = strdup("Alice");  // Allocated
person_cleanup(&p);        // Doesn't free name (borrowed by default)
```

✅ **No leak**:
```c
Person p;
person_init(&p);
p.name = strdup("Alice");
free(p.name);              // Manual free
person_cleanup(&p);
```

Or in the future with annotations:
```c
char* name __attribute__((structify(owned)));  // Auto-freed
```

### Problem: Incorrect hash values

```
Expected same hash, got different values
```

**Solution**:

Make sure you're comparing the same data:

```c
Person p1, p2;
person_init(&p1);
person_init(&p2);

p1.name = "Alice";
p2.name = "Alice";  // Different pointer!

// Hashes may differ (shallow pointer comparison)
uint64_t h1 = person_hash(&p1);
uint64_t h2 = person_hash(&p2);

// Use deep_equal for content comparison
assert(person_deep_equal(&p1, &p2));
```

---

## Generated Code Problems

### Problem: Generated function doesn't match expectations

**Solution**:

Use `structify info` to see what was parsed:

```bash
structify info person.h
```

This shows:
- Struct name
- Field names and types
- Ownership (borrowed/owned)

Verify the parsed information matches your intent.

### Problem: Copy is shallow instead of deep

**Solution**:

By default, non-owned pointers are shallow-copied. Future versions will support:

```c
char* data __attribute__((structify(deep_copy)));
```

For now, implement deep copy manually if needed:

```c
Person copy;
person_copy(&copy, &original);

// Manual deep copy for specific fields
if (original.data != NULL) {
    copy.data = malloc(original.data_size);
    memcpy(copy.data, original.data, original.data_size);
}
```

### Problem: Print output is truncated

```
TreeNode { value: 10, left: ... }
```

**Solution**:

This is cycle/depth protection. Max depth is 10 levels.

If you need deeper printing:
1. Manually call print functions at each level
2. Or modify generated code to increase depth limit

### Problem: Equality returns false for equal structs

**Solution**:

Use `deep_equal` instead of `equal`:

```c
// Shallow equality (pointer comparison)
assert(!person_equal(&p1, &p2));  // Different pointers

// Deep equality (content comparison)
assert(person_deep_equal(&p1, &p2));  // Same content
```

---

## Performance Issues

### Problem: Generated code is slow

**Solution**:

Generated code prioritizes correctness over speed. Optimizations:

1. **Compile with optimizations**:
```bash
gcc -O2 test.c generated.c
```

2. **Disable unused functions**:
```bash
structify generate person.h --only init --only cleanup
```

3. **Profile and optimize hot paths**:
```bash
gcc -pg test.c generated.c
./a.out
gprof a.out
```

### Problem: Large binary size

**Solution**:

Each struct generates ~200-300 lines of code. To reduce size:

1. **Strip debug symbols**:
```bash
gcc -O2 -s test.c generated.c  # -s strips symbols
```

2. **Generate only needed functions**:
```bash
structify generate person.h --only init --only cleanup
```

3. **Use LTO (Link-Time Optimization)**:
```bash
gcc -O2 -flto test.c generated.c
```

### Problem: Copy is slow for large structs

**Solution**:

Deep copying large nested structures is inherently slow. Options:

1. Use shallow copy (`person_equal` vs `person_deep_equal`)
2. Share data with reference counting (future feature)
3. Implement custom copy for specific fields

---

## CLI Issues

### Problem: Command not found

```
structify: command not found
```

**Solution**:

Run through cabal:

```bash
cabal run structify -- generate person.h
```

Or install locally:

```bash
cabal install
export PATH="$HOME/.cabal/bin:$PATH"
structify generate person.h
```

### Problem: Verbose mode doesn't show enough info

```bash
structify generate person.h -v
```

**Solution**:

For more debugging, check the test output:

```bash
cabal test --test-show-details=direct
```

Or run with debug print:

```bash
cabal run structify -- info person.h
```

---

## Getting Help

If you're still stuck:

1. **Check examples**: See [`examples/`](../examples/) for working code
2. **Read docs**: Full documentation in [`docs/`](../)
3. **Search issues**: Check [GitHub issues](https://github.com/yourusername/structify/issues)
4. **Ask questions**: Open a [discussion](https://github.com/yourusername/structify/discussions)
5. **Report bugs**: File an [issue](https://github.com/yourusername/structify/issues/new)

### When Reporting Issues

Please include:

1. **Your header file** (minimal reproduction)
2. **Command you ran**
3. **Error message** (full output)
4. **System info**:
   ```bash
   uname -a
   nix --version
   cabal --version
   ```

### Known Limitations

See [TASKS.md](TASKS.md) for current limitations:

- Limited preprocessor support
- Annotations not fully integrated
- No union support
- Some complex types unsupported

These are being worked on!

---

## Quick Fixes Checklist

- [ ] Are you in the Nix shell? (`nix develop`)
- [ ] Did you build the project? (`cabal build`)
- [ ] Is your header file simple (no `#` directives)?
- [ ] Are you linking the generated `.c` file?
- [ ] Did you initialize the struct before use?
- [ ] Are you freeing borrowed pointers manually?
- [ ] Did you check with `structify info`?

---

**Still having issues?** We're here to help! Open an issue on GitHub.

---

*Last updated: 2026-03-12*
