# Structify Examples

This directory contains example C headers demonstrating Structify's capabilities.

## Simple Examples

### 1. Point (`point.h`)
Basic struct with two integer fields.

```bash
structify generate point.h
```

Demonstrates:
- Simple primitive types
- Basic init/cleanup

### 2. Person (`person_minimal.h`)
Person with name, age, and array of children.

```bash
structify generate person_minimal.h
```

Demonstrates:
- Pointer fields
- Array fields with length tracking
- Recursive structs
- String handling

### 3. Binary Tree (`tree.h`)
Binary tree node with left and right children.

```bash
structify generate tree.h
```

Demonstrates:
- Recursive data structures
- Deep copy of trees
- Cycle detection in print

### 4. Linked List (`list.h`)
Simple linked list node.

```bash
structify generate list.h
```

Demonstrates:
- Self-referential pointers
- Cycle detection
- Traversal patterns

### 5. Rectangle (`rectangle.h`)
Rectangle with nested Point structs.

```bash
structify generate rectangle.h
```

Demonstrates:
- Nested struct values (not pointers)
- Compound types
- Multiple structs in one file

## Complex Examples

### Buffer (`complex/buffer.h`)
Dynamic buffer with capacity management.

Demonstrates:
- Dynamic arrays
- Capacity tracking
- Custom allocators (TODO)
- Pre/post hooks (TODO)

## Testing Examples

Generate and test any example:

```bash
# Generate code
cd examples/simple
structify generate tree.h

# Compile a test
cat > test_tree.c << 'EOF'
#include "tree_generated.h"
#include <stdio.h>

int main() {
    TreeNode root;
    treenode_init(&root);
    root.value = 10;

    treenode_print(&root, stdout, 0);
    printf("\n");

    treenode_cleanup(&root);
    return 0;
}
EOF

gcc -o test_tree test_tree.c tree_generated.c -I.
./test_tree
```

## Annotated Examples (Coming Soon)

Examples with `__attribute__((structify(...)))` annotations for advanced features.

See `person_annotated.h` for a preview.
