const std = @import("std");

usingnamespace @import("main");

test "rectangles intersect" {
    var r1 = Rectangle{
        .x = 10,
        .y = 10,
        .width = 10,
        .height = 10,
    };

    var r2 = Rectangle{
        .x = 15,
        .y = 15,
        .width = 10,
        .height = 10,
    };

    std.testing.expect(rectanglesIntersect(r1, r2));
}

test "rectangles from position" {
    var pos = Position{
        .x = 10,
        .y = 10,
        .fx = 10.0,
        .fy = 10.0,
    };
    var rect = Rectangle{
        .x = 320,
        .y = 320,
        .width = 32,
        .height = 32,
    };

    var rectP = truePositionRect(pos);

    std.testing.expect(rect.x == rectP.x and
        rect.y == rectP.y and
        rect.width == rectP.width and
        rect.height == rectP.height);
}
