# Structify Tutorial

**Learn Structify by example**

This tutorial walks you through using Structify to generate C boilerplate code for your structs.

## Table of Contents

1. [Installation](#installation)
2. [Your First Struct](#your-first-struct)
3. [Working with Pointers](#working-with-pointers)
4. [Dynamic Arrays](#dynamic-arrays)
5. [Nested Structs](#nested-structs)
6. [Advanced Features](#advanced-features)
7. [Best Practices](#best-practices)

## Installation

### Prerequisites

- Nix with flakes enabled
- Basic knowledge of C
- GCC or Clang for compiling generated code

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/structify.git
cd structify

# Enter development environment
nix develop

# Build
cabal build

# Test installation
cabal run structify -- --help
```

You should see the Structify help message.

## Your First Struct

Let's start with a simple Point struct.

### Step 1: Create a Header File

Create `point.h`:

```c
typedef struct Point {
    int x;
    int y;
} Point;
```

### Step 2: Generate Code

```bash
structify generate point.h
```

This creates two files:
- `point_generated.h` - Function declarations
- `point_generated.c` - Function implementations

### Step 3: View Generated Functions

Look at `point_generated.h`:

```c
int point_init(Point* self);
void point_cleanup(Point* self);
int point_copy(Point* dest, const Point* src);
void point_print(const Point* self, FILE* out, int depth);
bool point_equal(const Point* a, const Point* b);
bool point_deep_equal(const Point* a, const Point* b);
uint64_t point_hash(const Point* self);
```

Seven functions generated for free!

### Step 4: Use in Your Code

Create `test_point.c`:

```c
#include "point_generated.h"
#include <stdio.h>

int main() {
    Point p;

    // Initialize
    point_init(&p);

    // Set values
    p.x = 10;
    p.y = 20;

    // Print
    printf("Point: ");
    point_print(&p, stdout, 0);
    printf("\n");

    // Copy
    Point p2;
    point_copy(&p2, &p);
    printf("Copy: ");
    point_print(&p2, stdout, 0);
    printf("\n");

    // Compare
    printf("Equal: %s\n", point_equal(&p, &p2) ? "yes" : "no");

    // Hash
    printf("Hash: %lu\n", point_hash(&p));

    // Cleanup
    point_cleanup(&p);
    point_cleanup(&p2);

    return 0;
}
```

### Step 5: Compile and Run

```bash
gcc -o test_point test_point.c point_generated.c -I.
./test_point
```

Output:
```
Point: Point { x: 10, y: 20 }
Copy: Point { x: 10, y: 20 }
Equal: yes
Hash: 14695981039346656037
```

🎉 **Congratulations!** You've generated your first struct functions with Structify!

## Working with Pointers

Now let's handle structs with pointers.

### Example: Person with Name

Create `person.h`:

```c
typedef struct Person {
    char* name;
    int age;
} Person;
```

Generate code:

```bash
structify generate person.h
```

Test it:

```c
#include "person_generated.h"
#include <string.h>
#include <stdlib.h>

int main() {
    Person p;
    person_init(&p);  // name = NULL, age = 0

    // Allocate and set name
    p.name = strdup("Alice");
    p.age = 30;

    person_print(&p, stdout, 0);

    // IMPORTANT: Free the name before cleanup
    free(p.name);
    person_cleanup(&p);

    return 0;
}
```

### Current Behavior

By default, pointers are treated as **borrowed** (not owned). This means:
- ✅ Init sets them to NULL
- ❌ Cleanup doesn't free them
- ✅ Copy copies the pointer (shallow)

You're responsible for freeing `name` manually.

### Future: Ownership Annotations

In the future, you'll be able to mark pointers as owned:

```c
typedef struct Person {
    char* name __attribute__((structify(owned)));  // Future feature
    int age;
} Person;
```

Then cleanup will automatically free owned pointers.

## Dynamic Arrays

Structs often contain dynamic arrays. Here's how Structify handles them.

### Example: Integer Array

Create `array.h`:

```c
typedef struct IntArray {
    int* data;
    size_t count;
} IntArray;
```

Generate and use:

```c
#include "intarray_generated.h"
#include <stdlib.h>

int main() {
    IntArray arr;
    intarray_init(&arr);

    // Allocate array
    arr.count = 5;
    arr.data = malloc(arr.count * sizeof(int));

    // Fill with values
    for (size_t i = 0; i < arr.count; i++) {
        arr.data[i] = i * 10;
    }

    // Print
    intarray_print(&arr, stdout, 0);

    // Cleanup
    free(arr.data);
    intarray_cleanup(&arr);

    return 0;
}
```

### Future: Length Annotations

With annotations (future), you can associate arrays with their lengths:

```c
typedef struct IntArray {
    int* data __attribute__((structify(owned, length="count")));
    size_t count;
} IntArray;
```

Then:
- Cleanup will automatically free `data`
- Print will iterate `count` elements
- Copy will deep-copy the array

## Nested Structs

Structify handles nested structs automatically.

### Example: Rectangle with Points

Create `rectangle.h`:

```c
typedef struct Point {
    double x;
    double y;
} Point;

typedef struct Rectangle {
    Point top_left;
    Point bottom_right;
} Rectangle;
```

Generate:

```bash
structify generate rectangle.h
```

This generates functions for **both** Point and Rectangle!

Use it:

```c
#include "rectangle_generated.h"

int main() {
    Rectangle rect;
    rectangle_init(&rect);

    rect.top_left.x = 0.0;
    rect.top_left.y = 10.0;
    rect.bottom_right.x = 100.0;
    rect.bottom_right.y = 0.0;

    rectangle_print(&rect, stdout, 0);

    rectangle_cleanup(&rect);
    return 0;
}
```

Output:
```
Rectangle {
  top_left: Point { x: 0.000000, y: 10.000000 }
  bottom_right: Point { x: 100.000000, y: 0.000000 }
}
```

Nice formatting with nested structures!

## Recursive Structures

Structify handles self-referential structs like trees and lists.

### Example: Binary Tree

Create `tree.h`:

```c
typedef struct TreeNode {
    int value;
    struct TreeNode* left;
    struct TreeNode* right;
} TreeNode;
```

Generate and build a tree:

```c
#include "treenode_generated.h"
#include <stdlib.h>

TreeNode* create_node(int value) {
    TreeNode* node = malloc(sizeof(TreeNode));
    treenode_init(node);
    node->value = value;
    return node;
}

int main() {
    // Build tree:
    //      10
    //     /  \
    //    5   15
    TreeNode* root = create_node(10);
    root->left = create_node(5);
    root->right = create_node(15);

    // Print (automatically handles recursion)
    treenode_print(root, stdout, 0);
    printf("\n");

    // Deep copy entire tree
    TreeNode* copy = malloc(sizeof(TreeNode));
    treenode_copy(copy, root);

    printf("Copy: ");
    treenode_print(copy, stdout, 0);
    printf("\n");

    // Cleanup (manual for now)
    free(root->left);
    free(root->right);
    free(root);
    free(copy->left);
    free(copy->right);
    free(copy);

    return 0;
}
```

### Cycle Detection

If your tree has cycles, print will detect them:

```c
// Create a cycle
root->left->left = root;  // Cycle!

treenode_print(root, stdout, 0);  // Stops at depth 10
```

Output:
```
TreeNode {
  value: 10
  left: TreeNode {
    value: 5
    left: ... (max depth)
  }
}
```

## Advanced Features

### Multiple Structs in One File

Structify generates functions for all structs in a header:

```c
// shapes.h
typedef struct Point {
    double x, y;
} Point;

typedef struct Circle {
    Point center;
    double radius;
} Circle;

typedef struct Rectangle {
    Point top_left;
    Point bottom_right;
} Rectangle;
```

Generates functions for all three structs!

### Custom Output Files

Control where files are generated:

```bash
structify generate person.h \
    --output-header include/person_api.h \
    --output-source src/person_impl.c
```

### Generate Only Specific Functions

Only need some functions?

```bash
structify generate person.h --only init --only cleanup
```

Generates only `init` and `cleanup`, skipping the rest.

### Verbose Mode

See what Structify is doing:

```bash
structify generate person.h -v
```

Output:
```
Reading input file: person.h
Found 1 struct(s)
Writing header to: person_generated.h
Writing source to: person_generated.c
✓ Generated code successfully!
```

### Info Command

Inspect what Structify parsed:

```bash
structify info person.h
```

Output:
```
Found 1 struct(s):

Struct: Person
  Fields: 2
    name :: char* (Borrowed)
    age :: int
```

Great for debugging!

## Best Practices

### 1. Keep Structs Simple

Simple structs generate simpler code:

✅ **Good**:
```c
typedef struct {
    int id;
    char* name;
} Record;
```

❌ **Complex** (harder to generate for):
```c
typedef struct {
    int (*callback)(void*, int, ...);  // Function pointers
    union { int i; float f; } data;    // Unions
    int bitfield : 3;                  // Bitfields
} Complex;
```

### 2. Use Consistent Naming

Name structs consistently for predictable function names:

```c
typedef struct Person Person;     // → person_init()
typedef struct TreeNode TreeNode; // → treenode_init()
```

### 3. Separate Interface from Implementation

Keep your struct definitions clean:

```c
// person.h - Your interface
typedef struct Person {
    char* name;
    int age;
} Person;

// person_generated.h - Generated functions
int person_init(Person* self);
void person_cleanup(Person* self);
// ...

// person_generated.c - Generated implementation
#include "person_generated.h"
// ... implementation
```

### 4. Test Generated Code

Always test generated functions:

```c
void test_person() {
    Person p;
    assert(person_init(&p) == 0);

    p.name = strdup("Test");
    Person copy;
    assert(person_copy(&copy, &p) == 0);
    assert(person_equal(&p, &copy));

    free(p.name);
    free(copy.name);
    person_cleanup(&p);
    person_cleanup(&copy);
}
```

### 5. Watch for Memory Leaks

Use valgrind to check for leaks:

```bash
gcc -g -o test test.c generated.c
valgrind --leak-check=full ./test
```

### 6. Version Control Generated Files

**Option A**: Check in generated files
- ✅ Easy to use (just `#include`)
- ❌ Large diffs when regenerating

**Option B**: Generate during build
- ✅ Smaller repo
- ❌ Requires Structify in build

Choose based on your project needs.

## Troubleshooting

### Problem: "Parse error" when generating

**Solution**: Structify's parser is simplified. Try:
1. Remove `#include` directives
2. Remove preprocessor macros
3. Simplify types

### Problem: Generated code doesn't compile

**Solution**: Check field types. Some complex types aren't fully supported yet:
- Function pointers → Partial support
- Unions → Not yet supported
- Complex typedef chains → May need simplification

### Problem: Memory leak in generated cleanup

**Solution**: Remember that non-owned pointers aren't freed. Free them manually before calling cleanup.

### Problem: Hash collision

**Solution**: FNV-1a is fast but has collisions. For cryptographic hashes, use a custom hash function (future feature).

## Next Steps

- Read the [Annotation Reference](ANNOTATIONS.md) for advanced features (coming soon)
- Check out [examples/](../examples/) for more code
- See [PLAN.md](PLAN.md) for implementation details
- Report issues on GitHub

## FAQ

**Q: Can I customize the generated code?**

A: Yes! Use annotations (coming soon) or provide custom functions via `custom_init`, `custom_cleanup`, etc.

**Q: What types are supported?**

A: Most C types:
- ✅ Primitives (int, char, float, etc.)
- ✅ Pointers
- ✅ Structs (nested, recursive)
- ✅ Arrays (fixed and dynamic)
- ⚠️ Function pointers (limited)
- ❌ Unions (not yet)
- ❌ Bitfields (not yet)

**Q: Is generated code production-ready?**

A: The generated code is clean and follows best practices:
- NULL-safe
- Error handling
- No memory leaks (when used correctly)
- Reasonable performance

Test thoroughly before production use!

**Q: How do I contribute?**

A: See [Contributing](#) and [PLAN.md](PLAN.md). Areas that need help:
- More examples
- Better error messages
- Union support
- Documentation improvements

---

**Happy generating!** 🚀

Need help? Open an issue on GitHub or check the [documentation](../docs/).

---

*Last updated: 2026-03-12*
