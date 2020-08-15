const std = @import("std");
const ArrayList = std.ArrayList;

const SnakeBit = @import("snake.zig").SnakeBit;
const SnakePart = @import("snake.zig").SnakePart;
const Food = @import("food.zig").Food;
const Shot = @import("shot.zig").Shot;
usingnamespace @import("entity.zig");

pub const Collision = struct {
    collision_type: CollisionType,
    is_snake_collision: bool,

    collider: Entity,
    collider_array_index: usize,

    target: Entity,
    target_array_index: usize,

    pub const CollisionType = enum {
        snakeSelf, snakeFood, shotSnake, shotFood
    };
};

pub const CollisionSystem = struct {
    allocator: *std.mem.Allocator,
    snakeIterator: *ArrayList(SnakeBit),
    foodIterator: *ArrayList(Food),
    shotsIterator: *ArrayList(Shot),
    collisions: ArrayList(Collision),
    history: ArrayList(Collision),

    pub fn detectCollisions(self: *CollisionSystem) !void {
        try self.history.appendSlice(self.collisions.items);
        self.collisions = ArrayList(Collision).init(self.allocator);

        try self.detectSelfCollision();
        try self.detectFoodCollision();
        try self.detectShotCollisions();
    }

    fn detectSelfCollision(self: *CollisionSystem) !void {
        var head = self.snakeIterator.items[0];

        for (self.snakeIterator.items) |*bit, i| {
            if (bit.entity.index == head.entity.index) {
                continue;
            }

            if (head.entity.position.x == bit.entity.position.x and
                head.entity.position.y == bit.entity.position.y)
            {
                const collision = Collision{
                    .collision_type = .snakeSelf,
                    .is_snake_collision = true,
                    .collider = head.entity,
                    .collider_array_index = 0,
                    .target = bit.entity,
                    .target_array_index = i,
                };

                try self.collisions.append(collision);
            }
        }
    }

    fn detectFoodCollision(self: *CollisionSystem) !void {
        var head = self.snakeIterator.items[0];

        for (self.foodIterator.items) |*f, i| {
            if (head.entity.position.x == f.entity.position.x and
                head.entity.position.y == f.entity.position.y)
            {
                const collision = Collision{
                    .collision_type = .snakeFood,
                    .is_snake_collision = false,
                    .collider = head.entity,
                    .collider_array_index = 0,
                    .target = f.entity,
                    .target_array_index = i,
                };
                try self.collisions.append(collision);
            }
        }
    }

    fn detectShotCollisions(self: *CollisionSystem) !void {
        for (self.shotsIterator.items) |*shot, i| {

            // detect snake hit
            for (self.snakeIterator.items) |*bit, si| {
                if (shot.hitEntity(&bit.entity)) {
                    const collision = Collision{
                        .collision_type = .shotSnake,
                        .is_snake_collision = true,
                        .collider = shot.entity,
                        .collider_array_index = i,
                        .target = bit.entity,
                        .target_array_index = si,
                    };

                    try self.collisions.append(collision);
                }
            }

            for (self.foodIterator.items) |*f, fi| {
                if (shot.hitEntity(&f.entity)) {
                    const collision = Collision{
                        .collision_type = .shotFood,
                        .is_snake_collision = true,
                        .collider = shot.entity,
                        .collider_array_index = i,
                        .target = f.entity,
                        .target_array_index = fi,
                    };

                    try self.collisions.append(collision);
                }
            }
        }
    }
};
