// Example: Rectangle with nested point
typedef struct Point {
    double x;
    double y;
} Point;

typedef struct Rectangle {
    Point top_left;
    Point bottom_right;
} Rectangle;
