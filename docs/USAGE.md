# How to Use Structify

## Quick Start

### 1. Basic Usage

Generate code from a C header file:

```bash
# From the project root
nix develop --command bash -c "cabal run structify -- generate your_header.h"
```

This will create:
- `your_header_generated.h` - Function declarations
- `your_header_generated.c` - Function implementations

### 2. With Verbose Output

```bash
nix develop --command bash -c "cabal run structify -- generate your_header.h -v"
```

### 3. Custom Output Files

```bash
nix develop --command bash -c "cabal run structify -- generate input.h -H output.h -C output.c"
```

Options:
- `-H FILE` or `--output-header FILE` - Specify header output file
- `-C FILE` or `--output-source FILE` - Specify source output file

## Available Commands

### 1. Generate Code

```bash
cabal run structify -- generate INPUT [OPTIONS]
```

Generates C functions for all structs in the input file.

### 2. Validate Annotations

```bash
cabal run structify -- validate INPUT
```

Validates that the header file can be parsed and enriched correctly.

### 3. Show Struct Info

```bash
cabal run structify -- info INPUT
```

Displays information about structs found in the header file.

## Example Workflow

### Step 1: Create a header file

```c
// point.h
struct Point {
    int x;
    int y;
};
```

### Step 2: Generate code

```bash
nix develop --command bash -c "cabal run structify -- generate point.h"
```

Output:
```
✓ Generated code successfully!
✓   Header: point_generated.h
✓   Source: point_generated.c
```

### Step 3: Use the generated code

```c
// main.c
#include "point_generated.h"

int main() {
    Point p;
    point_init(&p);
    p.x = 10;
    p.y = 20;

    point_print(&p, stdout, 0);

    point_cleanup(&p);
    return 0;
}
```

### Step 4: Compile

```bash
gcc -o main main.c point_generated.c
./main
```

## Generated Functions

For each struct, structify generates 7 functions:

1. **`init`** - Initialize all fields to default values
2. **`cleanup`** - Free all owned memory
3. **`copy`** - Deep copy the struct
4. **`print`** - Pretty-print to a file stream
5. **`equal`** - Shallow equality comparison
6. **`deep_equal`** - Deep equality comparison
7. **`hash`** - FNV-1a hash function

## Current Limitations

1. **No preprocessor support** - Comments and `#include` directives cause parse errors
   - Remove comments from input files
   - Don't use `#include` in the struct definition file

2. **Simple structs only** - Currently works best with:
   - Basic types (int, char, float, etc.)
   - Pointers
   - Arrays
   - Nested structs

## Tips

1. **Keep headers simple** - Use plain struct definitions without comments
2. **Use verbose mode** - Add `-v` to see what's happening
3. **Check validation** - Run `validate` command first to check for errors
4. **Use info command** - See what structs were found before generating

## Examples

See the `examples/simple/` directory for working examples:
- `person.h` - Struct with multiple fields
- `person_generated.{h,c}` - Generated code
- `test_person.c` - Test program
- `run_test.sh` - Integration test script

## Building Structify

If you want to install structify locally:

```bash
nix develop --command bash -c "cabal install"
```

This will install the `structify` binary to `~/.cabal/bin/`.

Then you can use it directly:

```bash
structify generate input.h
```
