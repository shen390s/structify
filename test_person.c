#include "person_minimal_generated.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    Person p;

    // Test init
    if (person_init(&p) != 0) {
        fprintf(stderr, "Init failed\n");
        return 1;
    }

    // Set some values
    p.name = strdup("Alice");
    p.age = 30;

    // Test print
    printf("Person: ");
    person_print(&p, stdout, 0);
    printf("\n\n");

    // Test copy
    Person p2;
    if (person_copy(&p2, &p) != 0) {
        fprintf(stderr, "Copy failed\n");
        return 1;
    }

    printf("Copied Person: ");
    person_print(&p2, stdout, 0);
    printf("\n\n");

    // Test equality
    printf("Shallow equal: %s\n", person_equal(&p, &p2) ? "true" : "false");
    printf("Deep equal: %s\n", person_deep_equal(&p, &p2) ? "true" : "false");

    // Test hash
    printf("Hash p: %lu\n", person_hash(&p));
    printf("Hash p2: %lu\n", person_hash(&p2));

    // Cleanup
    free(p.name);
    person_cleanup(&p);
    person_cleanup(&p2);

    printf("\n✓ All tests passed!\n");
    return 0;
}
