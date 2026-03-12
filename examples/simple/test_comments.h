// This is a test file with comments and preprocessor directives
#ifndef SIMPLE_TEST_H
#define SIMPLE_TEST_H

#include <stddef.h>
typedef unsigned long size_t;  // Define locally for parser

/* Multi-line comment
 * This should be handled
 */
typedef struct Point {
    int x;  // X coordinate
    int y;  // Y coordinate
} Point;

// Another struct with comments
typedef struct Person {
    char* name;     // Person's name
    int age;        // Person's age
    size_t count;   /* Count field */
} Person;

#endif // SIMPLE_TEST_H
