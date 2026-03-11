// Complex example: Buffer struct with custom allocators and hooks
#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>
#include <stdint.h>

typedef struct Buffer {
    uint8_t* data __attribute__((structify(owned, length="size", allocator="custom_alloc", deallocator="custom_free")));
    size_t size __attribute__((structify(default="0")));
    size_t capacity __attribute__((structify(default="0")));
    int flags __attribute__((structify(default="0", no_hash)));
} __attribute__((structify(
    pre_init="buffer_pre_init",
    post_init="buffer_post_init",
    pre_cleanup="buffer_pre_cleanup",
    post_cleanup="buffer_post_cleanup"
))) Buffer;

#endif // BUFFER_H
