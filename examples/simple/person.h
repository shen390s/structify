// Simple example: Person struct with basic annotations
#ifndef PERSON_H
#define PERSON_H

#include <stddef.h>

typedef struct Person {
    char* name;
    int age;
    struct Person** children;
    size_t num_children;
} Person;

#endif // PERSON_H
