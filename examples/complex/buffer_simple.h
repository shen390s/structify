// Complex example: Buffer struct (simplified for current parser)
#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>
#include <stdint.h>

// Define types locally for parser (includes are stripped)
typedef unsigned char uint8_t;
typedef unsigned long size_t;

/* Buffer struct for dynamic data storage
 *
 * Fields:
 * - data: Pointer to buffer data (owned, should be freed)
 * - size: Current size of valid data
 * - capacity: Total allocated capacity
 * - flags: Buffer flags for internal use
 */
typedef struct Buffer {
    uint8_t* data;     // Owned: should be freed in cleanup
    size_t size;       // Current size
    size_t capacity;   // Total capacity
    int flags;         // Internal flags
} Buffer;

// Future: Full annotation support will enable:
// - Custom allocators
// - Pre/post init hooks
// - Length field tracking
// - Selective hashing

#endif // BUFFER_H
