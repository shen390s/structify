// Test that multiple generated headers can be included together
#include "point_generated.h"
#include "person_generated.h"
#include <stdio.h>

int main() {
    // Test Point
    Point p;
    point_init(&p);
    p.x = 10;
    p.y = 20;

    printf("Point: ");
    point_print(&p, stdout, 0);
    printf("\n");

    point_cleanup(&p);

    // Test Person
    Person person;
    person_init(&person);

    printf("Person: ");
    person_print(&person, stdout, 0);
    printf("\n");

    person_cleanup(&person);

    printf("✓ Both headers included successfully!\n");
    return 0;
}
