#ifndef PERSON_TEST_H
#define PERSON_TEST_H

#include <stddef.h>
typedef unsigned long size_t;  // Define locally for parser

#ifndef __attribute__
#define __attribute__(x)
#endif

typedef struct Person {
    char* name __attribute__((structify(owned, default="NULL")));
    int age __attribute__((structify(default="0")));
    struct Person** children __attribute__((structify(owned, length="num_children", deep_copy)));
    size_t num_children __attribute__((structify(default="0")));
} Person __attribute__((structify()));

#endif
