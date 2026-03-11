// Test fixture: Simple struct for testing
#ifndef TEST_SIMPLE_H
#define TEST_SIMPLE_H

typedef struct Simple {
    int x __attribute__((structify(default="0")));
    int y __attribute__((structify(default="0")));
} Simple;

#endif // TEST_SIMPLE_H
