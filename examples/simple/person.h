// Simple example: Person struct with basic annotations
#ifndef PERSON_H
#define PERSON_H

#include <stddef.h>

typedef struct Person {
    char* name __attribute__((structify(owned, default="NULL")));
    int age __attribute__((structify(default="0")));
    struct Person** children __attribute__((structify(owned, length="num_children", deep_copy)));
    size_t num_children __attribute__((structify(default="0")));
} Person;

#endif // PERSON_H
