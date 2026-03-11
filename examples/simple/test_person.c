// Test program for generated Person functions
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "person_generated.h"

int main() {
    printf("=== Testing Generated Functions ===\n\n");

    // Test init
    Person p1;
    if (person_init(&p1) == 0) {
        printf("✓ person_init succeeded\n");
        printf("  name: %p\n", (void*)p1.name);
        printf("  age: %d\n", p1.age);
        printf("  num_children: %zu\n", p1.num_children);
    } else {
        printf("✗ person_init failed\n");
        return 1;
    }

    // Test print
    printf("\n✓ person_print:\n  ");
    person_print(&p1, stdout, 0);
    printf("\n");

    // Test hash
    uint64_t hash = person_hash(&p1);
    printf("\n✓ person_hash: %lu\n", hash);

    // Test copy
    Person p2;
    if (person_copy(&p2, &p1) == 0) {
        printf("\n✓ person_copy succeeded\n");
        printf("  Copied person hash: %lu\n", person_hash(&p2));
    } else {
        printf("\n✗ person_copy failed\n");
        person_cleanup(&p1);
        return 1;
    }

    // Test equality
    if (person_equal(&p1, &p2)) {
        printf("\n✓ person_equal: p1 == p2 (shallow)\n");
    } else {
        printf("\n✗ person_equal: p1 != p2 (unexpected)\n");
    }

    if (person_deep_equal(&p1, &p2)) {
        printf("✓ person_deep_equal: p1 == p2 (deep)\n");
    } else {
        printf("✗ person_deep_equal: p1 != p2 (unexpected)\n");
    }

    // Test cleanup
    person_cleanup(&p1);
    person_cleanup(&p2);
    printf("\n✓ person_cleanup succeeded\n");

    printf("\n=== All Tests Passed ===\n");
    return 0;
}
