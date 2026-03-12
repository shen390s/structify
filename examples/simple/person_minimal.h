typedef struct Person {
    char* name;
    int age;
    struct Person** children;
    unsigned long num_children;
} Person;
