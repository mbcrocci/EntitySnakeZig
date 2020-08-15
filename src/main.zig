const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

usingnamespace @import("raylib");
usingnamespace @import("components.zig");
usingnamespace @import("entity.zig");

const sprites = @import("sprite.zig");
const SnakeBit = @import("snake.zig").SnakeBit;
const Food = @import("food.zig").Food;
const Shot = @import("shot.zig").Shot;

const pu = @import("powerup.zig");
const cs = @import("collision.zig");

const flecs = @import("flecs");

const grid_size_x: i64 = 30;
const grid_size_y: i64 = 20;
pub const grid_cell_size: i64 = 32;
const screen_size_x: i64 = grid_size_x * grid_cell_size;
const screen_size_y: i64 = grid_size_y * grid_cell_size;

fn maybeCreateFood(rng: *std.rand.Random, food: *ArrayList(Food)) !void {
    if (food.items.len > 0) {
        return;
    }

    var x = rng.intRangeAtMost(i64, 0, grid_size_x - 1);
    var y = rng.intRangeAtMost(i64, 0, grid_size_y - 1);

    var ppt: ?pu.PowerUpTag = null;
    var prob = rng.float(f32);
    if (prob < 0.1) {
        ppt = .Invulnerable;
    } else if (prob < 0.2) {
        ppt = .Gun;
    } else if (prob < 0.3) {
        ppt = .ScoreMultiplier;
    }

    try food.append(Food{
        .entity = Entity.new(
            .{
                .x = x,
                .y = y,
            },
            .down,
        ),
        .power_up = ppt,
    });
}

fn renderBackground() void {
    var x: i64 = 0;
    var y: i64 = 0;
    const fgrid = @intToFloat(f32, grid_cell_size);

    while (y < grid_size_y) : (y += 1) {
        x = 0;
        while (x < grid_size_x) : (x += 1) {
            const fx = @intToFloat(f32, x);
            const fy = @intToFloat(f32, y);

            DrawTexturePro(sprites.grass.texture.*, sprites.grass.sourceRect, .{
                .x = fx * fgrid,
                .y = fy * fgrid,
                .width = fgrid,
                .height = fgrid,
            }, .{
                .x = 0,
                .y = 0,
            }, 0, LIGHTGRAY);
        }
    }
}

fn directionCanChange(current: Direction, next: Direction) bool {
    return !((current == next) or
        (current == .left and next == .right) or
        (current == .right and next == .left) or
        (current == .down and next == .up) or
        (current == .up and next == .down));
}

fn isOutsideScreen(position: *Position) bool {
    return position.x < 0 or
        position.x > grid_size_x or
        position.y < 0 or
        position.y > grid_size_y;
}

var is_debug: bool = false;

fn getRng(world: *flecs.ecs_world_t) callconv(.C) *Rng {
    var query = flecs.ecs_query_new(world, "Rng");
    var query_it = flecs.ecs_query_iter(query);
    _ = flecs.ecs_query_next(&query_it);

    return &query_it.column(Rng, 1)[0];
}

fn getIsAlive(world: *flecs.ecs_world_t) callconv(.C) *IsAlive {
    var query = flecs.ecs_query_new(world, "IsAlive");
    var query_it = flecs.ecs_query_iter(query);
    _ = flecs.ecs_query_next(&query_it);

    return &query_it.column(IsAlive, 1)[0];
}

fn getMoveQueue(world: *flecs.ecs_world_t) callconv(.C) *MoveQueue {
    var query = flecs.ecs_query_new(world, "[out] MoveQueue");
    var query_it = flecs.ecs_query_iter(query);
    _ = flecs.ecs_query_next(&query_it);
    return &query_it.column(MoveQueue, 1)[0];
}

fn getScore(world: *flecs.ecs_world_t) callconv(.C) *Score {
    var query = flecs.ecs_query_new(world, "Score");
    var query_it = flecs.ecs_query_iter(query);
    _ = flecs.ecs_query_next(&query_it);

    return &query_it.column(Score, 1)[0];
}

fn getSnakeHeadPosition(world: *flecs.ecs_world_t) callconv(.C) ?*Position {
    // return flecs.ecs_lookup(world, "SnakeHead");
    var query = flecs.ecs_query_new(world, "[in] SnakePart, Position");
    var query_it = flecs.ecs_query_iter(query);

    _ = flecs.ecs_query_next(&query_it);

    var parts = query_it.column(SnakePart, 1);
    var positions = query_it.column(Position, 2);

    var i: usize = 0;
    while (i < query_it.count) : (i += 1) {
        if (parts[i] == SnakePart.head) {
            return &positions[i];
        }
    }

    return null;
}

fn rectangleFromPosition(t: EntityType, pos: Position) Rectangle {
    const fx = @intToFloat(f32, pos.x);
    const fy = @intToFloat(f32, pos.y);
    const fgrid = @intToFloat(f32, grid_cell_size);

    return switch (t) {
        .shot => .{
            .x = fx * fgrid + (fgrid / 4.0),
            .y = fy * fgrid + (fgrid / 4.0),
            .width = fgrid / 2.0,
            .height = fgrid / 2.0,
        },
        else => .{
            .x = fx * fgrid,
            .y = fy * fgrid,
            .width = fgrid,
            .height = fgrid,
        },
    };
}

fn renderPowerups(world: *flecs.ecs_world_t) callconv(.C) void {
    var query = flecs.ecs_query_new(world, "TimedPowerUp");
    var query_it = flecs.ecs_query_iter(query);

    const power_ups = query_it.column(TimedPowerUp, 1);

    const pp_x = screen_size_x - 250;
    var pp_y: i32 = 20;

    DrawText("PowerUps", pp_x, pp_y, 24, WHITE);

    var pi: usize = 0;
    while (pi < query_it.count) : (pi += 1) {
        pp_y += 25;
        const pp = power_ups[pi];

        switch (pp.power_up) {
            .ScoreMultiplier => |p| {
                var st = FormatText("Score Multiplier: %02i", p);
                DrawText(st, pp_x, pp_y, 24, WHITE);
            },
            .Invulnerable => {
                DrawText("Invulnerable", pp_x, pp_y, 24, WHITE);
            },
            .Gun => {
                DrawText("Gun", pp_x, pp_y, 24, WHITE);
            },
        }
    }
}

fn renderSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    const entTypes = it.column(EntityType, 1);
    const positions = it.column(Position, 2);
    const animations = it.column(sprites.Animation, 3);

    BeginDrawing();
    defer EndDrawing();

    ClearBackground(WHITE);
    renderBackground();

    var scoreTxt = FormatText("Score: %02i", getScore(it.world.?).score);
    const x_pos = (screen_size_x / 2) - 35;
    DrawText(scoreTxt, x_pos, 20, 24, WHITE);

    //renderPowerups(it.world.?);

    if (is_debug) {
        const fps = GetFPS();
        var fpsTxt = FormatText("FPS: %02i", fps);
        DrawText(fpsTxt, 20, 20, 24, LIGHTGRAY);

        const frame_time = GetFrameTime();
        var frameTxt = FormatText("FT: %d ms", frame_time);
        // DrawText(frameTxt, 20, 45, 24, LIGHTGRAY);

        const head = getSnakeHeadPosition(it.world.?);
        // var posTxt = FormatText("Snake head at (%02i, %02i)", head_pos.x, head_pos.y);
        // DrawText(posTxt, 20, 60, 24, LIGHTGRAY);
    }

    var i: usize = 0;
    while (i < it.count) : (i += 1) {
        var rectangle = rectangleFromPosition(entTypes[i], positions[i]);

        DrawTexturePro(
            animations[i].texture.*,
            animations[i].sourceRect,
            rectangle,
            .{
                .x = 0,
                .y = 0,
            },
            0,
            WHITE,
        );
    }
}

fn moveSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    const entTypes = it.column(EntityType, 1);
    const positions = it.column(Position, 2);
    const directions = it.column(Direction, 3);
    const velocities = it.column(Velocity, 4);

    var queue = getMoveQueue(it.world.?);

    var i: usize = 0;
    while (i < it.count) : (i += 1) {
        var previous_direction: ?Direction = null;
        var current_direction: ?Direction = null;
        var queued_direction: ?Direction = queue.pop();

        if (entTypes[i] == .snakeBit or entTypes[i] == .food) {
            current_direction = directions[i];

            if (previous_direction) |new_direction| {
                directions[i] = new_direction;
            } else {
                if (queued_direction) |next_direction| {
                    const dir_change = directionCanChange(directions[i], next_direction);
                    if (dir_change) {
                        directions[i] = next_direction;
                    }
                }
            }

            previous_direction = current_direction;
        }

        var dt = it.delta_time;

        switch (directions[i]) {
            .right => positions[i].fx = positions[i].fx + velocities[i].vx * dt,
            .left => positions[i].fx = positions[i].fx - velocities[i].vx * dt,
            .down => positions[i].fy = positions[i].fy + velocities[i].vy * dt,
            .up => positions[i].fy = positions[i].fy - velocities[i].vy * dt,
        }

        if (positions[i].x != @floatToInt(i64, positions[i].fx)) {
            positions[i].x = @floatToInt(i64, positions[i].fx);
        }

        if (positions[i].y != @floatToInt(i64, positions[i].fy)) {
            positions[i].y = @floatToInt(i64, positions[i].fy);
        }

        const wrap = entTypes[i] != .shot;
        if (wrap) {
            positions[i].x = @mod(positions[i].x, grid_size_x);
            positions[i].fx = @mod(positions[i].fx, @intToFloat(f64, grid_size_x));

            positions[i].y = @mod(positions[i].y, grid_size_y);
            positions[i].fy = @mod(positions[i].fy, @intToFloat(f64, grid_size_y));
        }
    }
}

fn collisionSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    const positions = it.column(Position, 1);
    const entTypes = it.column(EntityType, 2);

    var world = flecs.World{ .world = it.world.? };
    var score = getScore(it.world.?);

    const headPosition = getSnakeHeadPosition(it.world.?);
    if (headPosition) |headPos| {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (positions[i].x == headPos.x and positions[i].y == headPos.y) {
                const ent = it.entities[i];
                world.set(ent, &ToClean{ .clean = true });

                std.debug.print("Collision!! {}\n", .{ent});

                if (entTypes[i] == EntityType.food) {
                    var fent = flecs.ecs_new_w_type(it.world.?, 0);
                    world.set(fent, &Spawnable{ .entType = EntityType.food });

                    std.debug.print("Spawning new food\n", .{});

                    score.score += 1;
                }
            }
        }
    }
}

fn inputSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    var queue = it.column(MoveQueue, 1);

    var dir: ?Direction = null;

    if (IsKeyDown(KeyboardKey.KEY_RIGHT)) {
        dir = Direction.right;
    } else if (IsKeyDown(KeyboardKey.KEY_LEFT)) {
        dir = Direction.left;
    } else if (IsKeyDown(KeyboardKey.KEY_UP)) {
        dir = Direction.up;
    } else if (IsKeyDown(KeyboardKey.KEY_DOWN)) {
        dir = Direction.down;
    }

    if (dir) |ndir| {
        queue[0].append(ndir);
    }

    if (IsKeyReleased(KeyboardKey.KEY_D)) {
        is_debug = if (is_debug) false else true;
    }
}

fn positionCheckerSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    const positions = it.column(Position, 1);

    var world = flecs.World{ .world = it.world.? };

    var i: usize = 0;
    while (i < it.count) : (i += 1) {
        if (isOutsideScreen(&positions[i])) {
            const ent = it.entities[i];
            world.set(ent, &ToClean{ .clean = true });
        }
    }
}

fn cleaningSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    var i: usize = 0;
    while (i < it.count) : (i += 1) {
        const ent = it.entities[i];
        flecs.ecs_delete(it.world.?, ent);
    }
}

fn spawningSystem(it: *flecs.ecs_iter_t) callconv(.C) void {
    const spawnables = it.column(Spawnable, 1);

    var world = flecs.World{ .world = it.world.? };

    var rng = getRng(it.world.?).rng.random;

    var i: usize = 0;
    while (i < it.count) : (i += 1) {
        var ent = flecs.ecs_new_w_type(it.world.?, 0);

        std.debug.print("Spawning: {} => {} \n", .{ spawnables[i], ent });

        switch (spawnables[i].entType) {
            .snakeBit => {},
            .food => {
                var x = rng.intRangeAtMost(i64, 0, grid_size_x - 1);
                var y = rng.intRangeAtMost(i64, 0, grid_size_y - 1);
                var fx = @intToFloat(f64, x);
                var fy = @intToFloat(f64, y);

                var ppt: ?pu.PowerUpTag = null;
                var prob = rng.float(f32);
                if (prob < 0.1) {
                    ppt = .Invulnerable;
                } else if (prob < 0.2) {
                    ppt = .Gun;
                } else if (prob < 0.3) {
                    ppt = .ScoreMultiplier;
                }

                world.set(ent, &EntityType.food);
                std.debug.print("Set EntityType\n", .{});
                world.set(ent, &Position{
                    .x = x,
                    .y = y,
                    .fx = fx,
                    .fy = fy,
                });
                std.debug.print("Set Position\n", .{});
                world.set(ent, &sprites.food);
                std.debug.print("Set animation\n", .{});
            },
            .shot => {},
        }
    }
}

fn handleInput(game: *Game) !void {
    if (IsKeyDown(KeyboardKey.KEY_RIGHT)) {
        try game.queued_moves.append(Direction.right);
    } else if (IsKeyDown(KeyboardKey.KEY_LEFT)) {
        try game.queued_moves.append(Direction.left);
    } else if (IsKeyDown(KeyboardKey.KEY_UP)) {
        try game.queued_moves.append(Direction.up);
    } else if (IsKeyDown(KeyboardKey.KEY_DOWN)) {
        try game.queued_moves.append(Direction.down);
    } else if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
        try game.maybeFireShot();
    } else if (IsKeyReleased(KeyboardKey.KEY_R)) {
        try game.restart();
    } else if (IsKeyReleased(KeyboardKey.KEY_D)) {
        is_debug = if (is_debug) false else true;
    }
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    InitWindow(screen_size_x, screen_size_y, "Power Snake");
    sprites.initTexture();

    var world = flecs.World.init();
    defer world.deinit();

    // Declare components
    _ = world.newComponent(EntityType);
    _ = world.newComponent(Position);
    _ = world.newComponent(Direction);
    _ = world.newComponent(Velocity);
    _ = world.newComponent(SnakePart);
    _ = world.newComponent(sprites.Animation);

    _ = world.newComponent(PowerUpTag);
    _ = world.newComponent(TimedPowerUp);
    _ = world.newComponent(Spawnable);
    _ = world.newComponent(ToClean);

    // Singleton Components
    _ = world.newComponent(IsAlive);
    _ = world.newComponent(Score);
    _ = world.newComponent(Rng);
    _ = world.newComponent(MoveQueue);

    // Init Singleton Entities
    const is_alive = flecs.ecs_new_w_entity(world.world, 0);
    world.setName(is_alive, "IsAlive");
    world.set(is_alive, &IsAlive{ .is_alive = true });

    const scoreEnt = flecs.ecs_new_w_entity(world.world, 0);
    world.setName(scoreEnt, "Score");
    world.set(scoreEnt, &Score{ .score = 0 });

    const rng = flecs.ecs_new_w_entity(world.world, 0);
    world.setName(rng, "Rng");
    world.set(rng, &Rng.init(allocator));

    const moveQueueEnt = flecs.ecs_new_w_entity(world.world, 0);
    world.setName(moveQueueEnt, "MoveQueue");
    world.set(moveQueueEnt, &MoveQueue{
        .moves = ArrayList(Direction).init(allocator),
    });

    // Init Systems
    world.newSystem("Input", .on_update, "[out] MoveQueue", inputSystem);

    world.newSystem("Move", .on_update, "[in] EntityType, [out] Position, [out] Direction, [in] Velocity", moveSystem);

    world.newSystem("Collision", .on_update, "[in] Position, [in] EntityType, [in] !SnakePart", collisionSystem);

    world.newSystem("PositionChecker", .on_update, "[in] Position", positionCheckerSystem);
    world.newSystem("Clean", .on_update, "[in] ToClean", cleaningSystem);

    world.newSystem("Spawner", .on_update, "[in] Spawnable", spawningSystem);

    world.newSystem("Render", .on_update, "[in] EntityType, [in] Position, [in] Animation", renderSystem);

    const head = flecs.ecs_new_w_type(world.world, 0);
    world.setName(head, "SnakeHead");
    world.set(head, &EntityType.snakeBit);
    world.set(head, &Direction.right);
    world.set(head, &Position{ .x = 10, .y = 5, .fx = 10.0, .fy = 5.0 });
    world.set(head, &Velocity{ .vx = 15, .vy = 15 });
    world.set(head, &SnakePart.head);
    world.set(head, &sprites.head);

    const f = flecs.ecs_new_w_type(world.world, 0);
    world.set(f, &EntityType.food);
    world.set(f, &Position{ .x = 25, .y = 10, .fx = 25.0, .fy = 5.0 });
    world.set(f, &sprites.food);

    // Only applies for rendering.
    world.setTargetFps(75);
    SetTargetFPS(75);

    // Main game loop
    while (!WindowShouldClose()) {
        if (getIsAlive(world.world).is_alive) {
            world.progress(0);
        }
    }

    CloseWindow(); // Close window and OpenGL context
}
