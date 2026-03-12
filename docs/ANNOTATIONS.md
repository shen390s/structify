# Structify Annotation Reference

**Complete guide to `__attribute__((structify(...)))` annotations**

## Overview

Structify uses GCC/Clang `__attribute__` syntax for annotations. Annotations can be applied at two levels:

1. **Field-level** - On individual struct fields
2. **Struct-level** - On the struct definition itself

## Quick Reference

### Field-Level Annotations

| Annotation | Type | Description | Example |
|------------|------|-------------|---------|
| `owned` | Ownership | Field owns memory, will be freed | `char* name __attribute__((structify(owned)))` |
| `borrowed` | Ownership | Field doesn't own memory | `void* ctx __attribute__((structify(borrowed)))` |
| `shared` | Ownership | Shared ownership (ref-counted) | Not yet implemented |
| `default="value"` | Init | Default initialization value | `int age __attribute__((structify(default="0")))` |
| `length="field"` | Array | Specifies length field for arrays | `int* data __attribute__((structify(length="count")))` |
| `custom_init="func"` | Init | Custom initialization function | `FILE* file __attribute__((structify(custom_init="open_file")))` |
| `custom_cleanup="func"` | Cleanup | Custom cleanup function | `FILE* file __attribute__((structify(custom_cleanup="close_file")))` |
| `deep_copy` | Copy | Enable deep copying for this field | `char* data __attribute__((structify(deep_copy)))` |
| `no_copy` | Copy | Skip this field in copy function | `pthread_mutex_t lock __attribute__((structify(no_copy)))` |
| `no_print` | Print | Don't print this field | `char* password __attribute__((structify(no_print)))` |
| `print_format="fmt"` | Print | Custom printf format | `time_t timestamp __attribute__((structify(print_format="%ld")))` |
| `no_equal` | Equal | Skip in equality comparison | `void* internal __attribute__((structify(no_equal)))` |
| `no_hash` | Hash | Skip in hash computation | `void* cache __attribute__((structify(no_hash)))` |
| `custom_hash="func"` | Hash | Custom hash function | `custom_t data __attribute__((structify(custom_hash="hash_custom")))` |
| `allocator="func"` | Memory | Custom allocator (default: malloc) | Not yet implemented |
| `deallocator="func"` | Memory | Custom deallocator (default: free) | Not yet implemented |

### Struct-Level Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `pre_init="func"` | Called before initialization | `} Person __attribute__((structify(pre_init="validate")));` |
| `post_init="func"` | Called after initialization | `} Person __attribute__((structify(post_init="setup")));` |
| `pre_cleanup="func"` | Called before cleanup | `} Person __attribute__((structify(pre_cleanup="save")));` |
| `post_cleanup="func"` | Called after cleanup | `} Person __attribute__((structify(post_cleanup="notify")));` |
| `no_init` | Don't generate init function | `} Person __attribute__((structify(no_init)));` |
| `no_cleanup` | Don't generate cleanup function | `} Person __attribute__((structify(no_cleanup)));` |
| `no_copy` | Don't generate copy function | `} Person __attribute__((structify(no_copy)));` |
| `no_print` | Don't generate print function | `} Person __attribute__((structify(no_print)));` |
| `no_equal` | Don't generate equality functions | `} Person __attribute__((structify(no_equal)));` |
| `no_hash` | Don't generate hash function | `} Person __attribute__((structify(no_hash)));` |
| `print_name="name"` | Custom name for print output | `} Person __attribute__((structify(print_name="User")));` |
| `hooks="file"` | External hook definitions | Not yet implemented |

## Detailed Documentation

### Ownership Annotations

#### `owned`

Marks a pointer field as owned by the struct. The cleanup function will free this memory.

```c
typedef struct {
    char* name __attribute__((structify(owned)));
} Person;
```

**Generated cleanup**:
```c
void person_cleanup(Person* self) {
    if (self->name != NULL) {
        free(self->name);
        self->name = NULL;
    }
}
```

**Default behavior**: Without `owned`, pointers are treated as `borrowed` by default.

#### `borrowed`

Marks a pointer field as borrowed (not owned). The cleanup function will NOT free this memory.

```c
typedef struct {
    const char* shared_string __attribute__((structify(borrowed)));
} Config;
```

**Generated cleanup**:
```c
void config_cleanup(Config* self) {
    self->shared_string = NULL;  // Don't free
}
```

**Use cases**:
- String literals
- References to globally managed resources
- Pointers to data owned by other structs

### Initialization Annotations

#### `default="value"`

Specifies the default value for a field during initialization.

```c
typedef struct {
    int port __attribute__((structify(default="8080")));
    bool enabled __attribute__((structify(default="true")));
    char* hostname __attribute__((structify(default="NULL")));
} ServerConfig;
```

**Generated init**:
```c
int serverconfig_init(ServerConfig* self) {
    self->port = 8080;
    self->enabled = true;
    self->hostname = NULL;
    return 0;
}
```

**Value syntax**:
- Must be valid C expression
- Wrap strings in quotes: `default="\"localhost\""`
- NULL for pointers: `default="NULL"`
- Numbers: `default="42"`
- Booleans: `default="true"` or `default="false"`

#### `custom_init="function"`

Calls a custom function to initialize this field.

```c
FILE* custom_init_file(void);  // Your custom init function

typedef struct {
    FILE* log __attribute__((structify(custom_init="custom_init_file")));
} Logger;
```

**Generated init**:
```c
int logger_init(Logger* self) {
    self->log = custom_init_file();
    if (self->log == NULL) {
        errno = EINVAL;
        return -1;
    }
    return 0;
}
```

**Requirements**:
- Function must return the field's type
- Function is called with no arguments
- NULL/0 return indicates failure

### Array Annotations

#### `length="field_name"`

Associates an array pointer with its length field.

```c
typedef struct {
    int* data __attribute__((structify(owned, length="count")));
    size_t count __attribute__((structify(default="0")));
} IntArray;
```

**Generated cleanup**:
```c
void intarray_cleanup(IntArray* self) {
    if (self->data != NULL) {
        free(self->data);
        self->data = NULL;
    }
    self->count = 0;
}
```

**Generated print**:
```c
void intarray_print(const IntArray* self, FILE* out, int depth) {
    fprintf(out, "data: [");
    for (size_t i = 0; i < self->count; i++) {
        fprintf(out, "%d", self->data[i]);
        if (i < self->count - 1) fprintf(out, ", ");
    }
    fprintf(out, "]");
}
```

**Use cases**:
- Dynamic arrays
- Variable-length data
- Buffer management

### Copy Annotations

#### `deep_copy`

Enables deep copying for pointer fields (copies pointed-to data, not just the pointer).

```c
typedef struct {
    char* data __attribute__((structify(owned, deep_copy)));
    size_t size;
} Buffer;
```

**Generated copy**:
```c
int buffer_copy(Buffer* dest, const Buffer* src) {
    if (src->data != NULL) {
        dest->data = malloc(src->size);
        if (dest->data == NULL) return -1;
        memcpy(dest->data, src->data, src->size);
    }
    dest->size = src->size;
    return 0;
}
```

**Default behavior**: `owned` pointers are deep-copied by default. Use `deep_copy` to override for `borrowed` pointers.

#### `no_copy`

Excludes a field from the copy function.

```c
typedef struct {
    int value;
    pthread_mutex_t lock __attribute__((structify(no_copy)));
} ThreadSafe;
```

**Generated copy**:
```c
int threadsafe_copy(ThreadSafe* dest, const ThreadSafe* src) {
    dest->value = src->value;
    // lock is NOT copied
    return 0;
}
```

**Use cases**:
- Mutexes and locks
- File descriptors
- Non-copyable resources

### Print Annotations

#### `no_print`

Excludes a field from the print function.

```c
typedef struct {
    char* username;
    char* password __attribute__((structify(no_print)));
} Credentials;
```

**Generated print**:
```c
void credentials_print(const Credentials* self, FILE* out, int depth) {
    fprintf(out, "username: %s\n", self->username);
    // password is NOT printed
}
```

**Use cases**:
- Sensitive data (passwords, keys)
- Large binary data
- Internal implementation details

#### `print_format="format"`

Specifies a custom printf format string.

```c
typedef struct {
    uint64_t timestamp __attribute__((structify(print_format="%lu")));
    double price __attribute__((structify(print_format="$%.2f")));
} Order;
```

**Generated print**:
```c
void order_print(const Order* self, FILE* out, int depth) {
    fprintf(out, "timestamp: %lu\n", self->timestamp);
    fprintf(out, "price: $%.2f\n", self->price);
}
```

### Equality Annotations

#### `no_equal`

Excludes a field from equality comparisons.

```c
typedef struct {
    int id;
    time_t created_at __attribute__((structify(no_equal)));
} Record;
```

**Generated equal**:
```c
bool record_equal(const Record* a, const Record* b) {
    if (a->id != b->id) return false;
    // created_at is NOT compared
    return true;
}
```

**Use cases**:
- Timestamps
- Cached values
- Transient data

### Hash Annotations

#### `no_hash`

Excludes a field from hash computation.

```c
typedef struct {
    int key;
    char* cached_value __attribute__((structify(no_hash)));
} CacheEntry;
```

**Generated hash**:
```c
uint64_t cacheentry_hash(const CacheEntry* self) {
    uint64_t hash = FNV_OFFSET_BASIS;
    hash = fnv1a_hash(&self->key, sizeof(self->key), hash);
    // cached_value is NOT hashed
    return hash;
}
```

**Use cases**:
- Cached/derived values
- Metadata
- Non-identifying fields

#### `custom_hash="function"`

Uses a custom hash function for this field.

```c
uint64_t hash_custom_type(const CustomType* value);

typedef struct {
    CustomType data __attribute__((structify(custom_hash="hash_custom_type")));
} Container;
```

**Requirements**:
- Function signature: `uint64_t func(const FieldType* value)`
- Must handle NULL pointers if field is a pointer

### Cleanup Annotations

#### `custom_cleanup="function"`

Calls a custom cleanup function for this field.

```c
void custom_close_file(FILE** fp);

typedef struct {
    FILE* log __attribute__((structify(custom_cleanup="custom_close_file")));
} Logger;
```

**Generated cleanup**:
```c
void logger_cleanup(Logger* self) {
    if (self->log != NULL) {
        custom_close_file(&self->log);
        self->log = NULL;
    }
}
```

**Requirements**:
- Function signature: `void func(FieldType* field_ptr)`
- Function receives a pointer to the field
- Function should set pointer to NULL if applicable

### Struct-Level Hooks

#### Pre/Post Init Hooks

Called before and after initialization.

```c
int validate_person(Person* self);
int setup_person(Person* self);

typedef struct {
    char* name;
    int age;
} Person __attribute__((structify(
    pre_init="validate_person",
    post_init="setup_person"
)));
```

**Generated init**:
```c
int person_init(Person* self) {
    // Pre-init hook
    if (validate_person(self) != 0) return -1;

    // Initialize fields
    self->name = NULL;
    self->age = 0;

    // Post-init hook
    if (setup_person(self) != 0) return -1;

    return 0;
}
```

#### Pre/Post Cleanup Hooks

Called before and after cleanup.

```c
void save_person(Person* self);
void notify_removed(Person* self);

typedef struct {
    char* name;
} Person __attribute__((structify(
    pre_cleanup="save_person",
    post_cleanup="notify_removed"
)));
```

### Disabling Function Generation

#### `no_init`, `no_cleanup`, etc.

Prevents generation of specific functions.

```c
// POD type - no init/cleanup needed
typedef struct {
    int x;
    int y;
} Point __attribute__((structify(no_init, no_cleanup)));

// Generate only print function
typedef struct {
    int value;
} DebugOnly __attribute__((structify(
    no_init,
    no_cleanup,
    no_copy,
    no_equal,
    no_hash
)));
```

## Combining Annotations

Multiple annotations can be combined with commas:

```c
typedef struct {
    char* name __attribute__((structify(owned, default="NULL", no_hash)));
    int* data __attribute__((structify(owned, length="count", deep_copy)));
    size_t count __attribute__((structify(default="0")));
} Example;
```

## Portability Macros

For MSVC compatibility, add these macros:

```c
#ifndef __attribute__
#define __attribute__(x)
#endif

#ifndef structify
#define structify(...) /* empty */
#endif
```

With these macros, annotated code compiles on non-GCC/Clang compilers.

## Current Status

✅ **Implemented**: Basic code generation (works with default annotations)
🚧 **In Progress**: Full annotation parsing and integration
📋 **Planned**: Custom allocators, hooks, validation functions

See [TASKS.md](TASKS.md) for roadmap.

## Examples

See [examples/](../examples/) directory for complete examples:

- `person_annotated.h` - Comprehensive annotation usage
- `buffer.h` - Dynamic array with length tracking
- More coming soon!

## FAQ

### Q: What happens if I don't use annotations?

A: Structify generates sensible defaults:
- All pointers are `borrowed` (not freed in cleanup)
- Fields initialized to 0/NULL
- All fields included in all functions

### Q: Can I mix annotated and non-annotated fields?

A: Yes! Fields without annotations use defaults.

### Q: What if my field needs custom behavior?

A: Use `custom_init`, `custom_cleanup`, or `custom_hash` annotations to integrate your custom functions.

### Q: How do I debug annotation parsing?

A: Use the `validate` and `info` commands:

```bash
structify validate myfile.h
structify info myfile.h
```

---

**Last Updated**: 2026-03-12
**Status**: Living document (updated as features are implemented)
