const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

usingnamespace @import("raylib");
usingnamespace @import("components.zig");

const sprites = @import("sprite.zig");
const pu = @import("powerup.zig");

// const flecs = @import("flecs");
const ecs = @import("ecs");

const Metrics = struct {
    avgMoveIter: f64,
    moveIterations: u64,
    moveTimes: ArrayList(u64),

    avgCollisionIter: f64,
    collisionIterations: u64,
    collisionTimes: ArrayList(u64),

    avgRenderingIter: f64,
    renderingIterations: u64,
    renderingTimes: ArrayList(u64),

    fn avg(self: *Metrics) void {
        var ms: f64 = 0;
        for (self.moveTimes.items) |mt| {
            ms += @intToFloat(f64, mt);
        }
        self.avgMoveIter = ms / @intToFloat(f64, self.moveIterations);

        var cls: f64 = 0;
        for (self.collisionTimes.items) |ct| {
            cls += @intToFloat(f64, ct);
        }
        self.avgCollisionIter = cls / @intToFloat(f64, self.collisionIterations);

        var rs: f64 = 0;
        for (self.moveTimes.items) |rt| {
            rs += @intToFloat(f64, rt);
        }
        self.avgRenderingIter = rs / @intToFloat(f64, self.renderingIterations);
    }

    fn init() Metrics {
        return Metrics{
            .avgMoveIter = 0,
            .moveIterations = 1,

            .avgCollisionIter = 0,
            .collisionIterations = 1,

            .avgRenderingIter = 0,
            .renderingIterations = 1,

            .moveTimes = ArrayList(u64).init(std.heap.c_allocator),
            .collisionTimes = ArrayList(u64).init(std.heap.c_allocator),
            .renderingTimes = ArrayList(u64).init(std.heap.c_allocator),
        };
    }
};

var metrics = Metrics.init();

var is_debug: bool = true;
var snakeIndex: c_int = 1;

const grid_size_x: i64 = 30;
const grid_size_y: i64 = 20;
pub const grid_cell_size: i64 = 32;
const screen_size_x: i64 = grid_size_x * grid_cell_size;
const screen_size_y: i64 = grid_size_y * grid_cell_size;

fn directionCanChange(current: Direction, next: Direction) bool {
    return !((current == next) or
        (current == .left and next == .right) or
        (current == .right and next == .left) or
        (current == .down and next == .up) or
        (current == .up and next == .down));
}

fn isOutsideScreen(position: *const Position) bool {
    return position.x < 0 or
        position.x > grid_size_x or
        position.y < 0 or
        position.y > grid_size_y;
}

fn getRng() std.rand.Random {
    //var rng = reg.singletons.getConst(Rng).rng.random;
    return std.rand.Xoroshiro128.init(@intCast(u64, std.time.milliTimestamp())).random;
}

fn getSnakeHeadPosition(reg: *ecs.Registry) ?*Position {
    var view = reg.view(.{ SnakePart, Position }, .{});

    var iter = view.iterator();
    while (iter.next()) |entity| {
        const part = view.getConst(SnakePart, entity);
        var pos = view.get(Position, entity);

        if (part == SnakePart.head) {
            return pos;
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

fn truePositionRect(t: EntityType, pos: Position) Rectangle {
    const fgrid = @intToFloat(f64, grid_cell_size);
    return switch (t) {
        .shot => .{
            .x = @floatCast(f32, pos.fx * fgrid + (fgrid / 4.0)),
            .y = @floatCast(f32, pos.fy * fgrid + (fgrid / 4.0)),
            .width = @floatCast(f32, fgrid / 2.0),
            .height = @floatCast(f32, fgrid / 2.0),
        },
        else => .{
            .x = @floatCast(f32, pos.fx * fgrid),
            .y = @floatCast(f32, pos.fy * fgrid),
            .width = @floatCast(f32, fgrid),
            .height = @floatCast(f32, fgrid),
        },
    };
}

fn rectanglesIntersect(r1: Rectangle, r2: Rectangle) bool {
    return r1.x < r2.x + r2.width and
        r1.x + r1.width > r2.x and
        r1.y > r2.y + r2.height and
        r1.y + r1.height < r2.y;
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

fn renderPowerups(reg: *ecs.Registry) void {
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

fn renderSystem(reg: *ecs.Registry) void {
    var timer = std.time.Timer.start() catch unreachable;
    defer {
        EndDrawing();

        var end = timer.lap();

        metrics.renderingIterations += 1;
        metrics.renderingTimes.append(end) catch unreachable;
    }

    var view = reg.view(.{ EntityType, Position, sprites.Animation }, .{});

    BeginDrawing();
    //defer EndDrawing();

    ClearBackground(WHITE);
    renderBackground();

    var scoreTxt = FormatText("Score: %02i", reg.singletons.get(Score).score);
    const x_pos = (screen_size_x / 2) - 35;
    DrawText(scoreTxt, x_pos, 20, 24, WHITE);

    //renderPowerups(it.world.?);

    if (is_debug) {
        const fps = GetFPS();
        var fpsTxt = FormatText("FPS: %02i", fps);
        DrawText(fpsTxt, 20, 20, 24, LIGHTGRAY);

        var entCount: i64 = 0;
        var ents = reg.entities();
        while (ents.next()) |ent| {
            entCount += 1;
        }

        var countTxt = FormatText("Entities: %i", entCount);
        DrawText(countTxt, 20, 40, 24, LIGHTGRAY);

        if (reg.singletons.get(MoveQueue).peek()) |nextDir| {
            var txt = switch (nextDir) {
                .right => FormatText("Last dir: right"),
                .left => FormatText("Last dir: left"),
                .down => FormatText("Last dir: down"),
                .up => FormatText("Last dir: up"),
            };

            DrawText(txt, 20, 60, 24, LIGHTGRAY);
        }

        var moveMetricTxt = FormatText("Move: %2.02f ms", metrics.avgMoveIter / 1000000);
        DrawText(moveMetricTxt, 20, 80, 24, LIGHTGRAY);

        // var collisionMetricTxt = FormatText("Coll: %2.02f ms", metrics.avgCollisionIter / 1000000);
        // DrawText(collisionMetricTxt, 20, 100, 24, LIGHTGRAY);

        var renderingMetricTxt = FormatText("Rend: %2.02f ms", metrics.avgRenderingIter / 1000000);
        DrawText(renderingMetricTxt, 20, 100, 24, LIGHTGRAY);
    }

    var iter = view.iterator();
    while (iter.next()) |entity| {
        const entType = view.getConst(EntityType, entity);
        const pos = view.getConst(Position, entity);
        const animation = view.getConst(sprites.Animation, entity);

        const r = rectangleFromPosition(entType, pos);

        DrawTexturePro(
            animation.texture.*,
            animation.sourceRect,
            r,
            .{
                .x = 0,
                .y = 0,
            },
            0,
            WHITE,
        );

        if (is_debug) {
            if (entType == .snakeBit) {
                if (reg.tryGet(SnakePart, entity)) |part| {
                    switch (part.*) {
                        .head => DrawRectangleLinesEx(r, 2, WHITE),
                        .body => DrawRectangleLinesEx(r, 2, YELLOW),
                        .tail => DrawRectangleLinesEx(r, 2, RED),
                    }
                }
                // if (reg.tryGet(SnakeIndex, entity)) |index| {
                //     var t = FormatText("%1i", index.*);
                //     DrawText(t, @floatToInt(i32, r.x + r.width / 2), @floatToInt(i32, r.y + r.height / 2), 24, YELLOW);
                // }
            } else {
                DrawRectangleLinesEx(r, 2, WHITE);
            }

            // var t = FormatText("(%2i, %2i)", pos.x, pos.y);
            // DrawText(t, @floatToInt(i32, r.x + r.width / 2), @floatToInt(i32, r.y + r.height / 2), 24, YELLOW);

            if (reg.tryGet(Direction, entity)) |direction| {
                var debug_line: Vector2 = switch (direction.*) {
                    .right => .{ .x = r.x + 100, .y = r.y + 16 },
                    .left => .{ .x = r.x - 100, .y = r.y + 16 },
                    .down => .{ .x = r.x + 16, .y = r.y + 100 },
                    .up => .{ .x = r.x + 16, .y = r.y - 100 },
                };
                // if (reg.tryGet(SnakeIndex, entity)) |index| {
                //     debug_line.x += @intToFloat(f32, index.*.index * 10);
                //     // debug_line.y += @intToFloat(f32, index.*.index * 10);
                // }

                DrawLineEx(.{ .x = r.x + 16, .y = r.y + 16 }, debug_line, 2, WHITE);
            }
        }
    }
}

fn inputSystem(reg: *ecs.Registry) void {
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
        var queue = reg.singletons.get(MoveQueue);
        queue.append(ndir);
    }

    if (IsKeyReleased(KeyboardKey.KEY_D)) {
        is_debug = if (is_debug) false else true;
    }

    // TODO
    // 1. Fire Shot
    // 2. Restart game
}

fn getSnakeGroup(reg: *ecs.Registry) ecs.OwningGroup {
    var group = reg.group(.{ SnakePart, Position, Direction, Velocity, sprites.Animation }, .{}, .{});

    const SortCtx = struct {
        fn sort(this: void, a: SnakePart, b: SnakePart) bool {
            switch (a) {
                .head => {
                    return false;
                },
                .body => {
                    switch (b) {
                        .head => {
                            return true;
                        },
                        .body => {
                            return true;
                        },
                        .tail => {
                            return false;
                        },
                    }
                },
                .tail => {
                    return true;
                },
            }
        }
    };

    const SortCtx2 = struct {
        fn sort(this: void, a: SnakeIndex, b: SnakeIndex) bool {
            return a.index > b.index;
        }
    };

    // group.sort(SnakePart, {}, SortCtx.sort);
    group.sort(SnakeIndex, {}, SortCtx2.sort);

    // var iter = group.iterator(struct { part: *SnakePart });
    // while(iter.next()) |e| { std.debug.print("{}|",.{e.part}); }
    // std.debug.print("\n", .{});

    return group;
}

fn snakeMovementSystem(reg: *ecs.Registry, dt: f64) void {
    var next_position: ?Position = null;
    var next_direction: ?Direction = null;

    var queue = reg.singletons.get(MoveQueue);
    var group = getSnakeGroup(reg);

    var giter = group.iterator(struct {
        part: *SnakePart,
        position: *Position,
        direction: *Direction,
        velocity: *Velocity,
    });

    while (giter.next()) |e| {
        if (e.part.* == .head) {
            next_position = e.position.*;
            next_direction = e.direction.*;

            const queued_direction = queue.pop();
            if (queued_direction) |dir| {
                const dir_change = directionCanChange(e.direction.*, dir);
                if (dir_change) {
                    e.direction.* = dir;
                }
            }

            switch (e.direction.*) {
                .right => e.position.fx = e.position.fx + e.velocity.vx * dt,
                .left => e.position.fx = e.position.fx - e.velocity.vx * dt,
                .down => e.position.fy = e.position.fy + e.velocity.vy * dt,
                .up => e.position.fy = e.position.fy - e.velocity.vy * dt,
            }
        } else if (e.part.* == .tail) {
            if (next_position) |np| {
                if (next_direction) |nd| {
                    e.position.* = np;
                    e.direction.* = nd;
                }
            }
        } else {
            const tmp_position = e.position.*;
            const tmp_direction = e.direction.*;

            if (next_position) |np| {
                if (next_direction) |nd| {
                    e.position.* = np;
                    e.direction.* = nd;
                }
            }

            next_position = tmp_position;
            next_direction = tmp_direction;
        }

        if (e.position.x != @floatToInt(i64, e.position.fx)) {
            e.position.x = @floatToInt(i64, e.position.fx);
        }

        if (e.position.y != @floatToInt(i64, e.position.fy)) {
            e.position.y = @floatToInt(i64, e.position.fy);
        }

        e.position.x = @mod(e.position.x, grid_size_x);
        e.position.fx = @mod(e.position.fx, @intToFloat(f64, grid_size_x));

        e.position.y = @mod(e.position.y, grid_size_y);
        e.position.fy = @mod(e.position.fy, @intToFloat(f64, grid_size_y));
    }
}

fn moveSystem(reg: *ecs.Registry, dt: f64) void {
    var timer = std.time.Timer.start() catch unreachable;

    snakeMovementSystem(reg, dt);

    var view = reg.view(.{ EntityType, Position, Direction, Velocity }, .{SnakePart});
    var iter = view.iterator();

    while (iter.next()) |entity| {
        const entType = view.getConst(EntityType, entity);
        var position = view.get(Position, entity);
        var direction = view.get(Direction, entity);
        const velocity = view.getConst(Velocity, entity);

        position.fx = position.fx + velocity.vx * dt;
        position.fy = position.fy + velocity.vy * dt;

        if (position.x != @floatToInt(i64, position.fx)) {
            position.x = @floatToInt(i64, position.fx);
        }

        if (position.y != @floatToInt(i64, position.fy)) {
            position.y = @floatToInt(i64, position.fy);
        }
    }
    var end = timer.lap();

    metrics.moveIterations += 1;
    metrics.moveTimes.append(end) catch unreachable;
}

fn collisionSystem(reg: *ecs.Registry) void {
    var timer = std.time.Timer.start() catch unreachable;

    var score = reg.singletons.get(Score);
    var is_alive = reg.singletons.get(IsAlive);

    var headPos = Position{ .x = -1, .y = -1, .fx = -1, .fy = -1 };

    var snakeView = reg.view(.{ SnakePart, Position }, .{});
    var snakeIter = snakeView.iterator();

    while (snakeIter.next()) |snakeEnt| {
        const part = snakeView.getConst(SnakePart, snakeEnt);
        const position = snakeView.getConst(Position, snakeEnt);

        if (part == .head) {
            headPos = position;
        }

        if (position.x == headPos.x and position.y == headPos.y) {
            is_alive.is_alive = false;
        }
    }

    // Counldn't find the snake's head
    if (headPos.x < 0) {
        return;
    }

    var view = reg.view(.{ Position, EntityType }, .{ SnakePart, ToClean });
    var iter = view.iterator();

    while (iter.next()) |entity| {
        const position = view.getConst(Position, entity);
        const entType = view.getConst(EntityType, entity);

        if (position.x == headPos.x and
            position.y == headPos.y)
        {
            switch (entType) {
                .food => {
                    reg.add(entity, ToClean{ .clean = true });

                    var new_food = reg.create();
                    reg.add(new_food, Spawnable{ .entType = EntityType.food });
                    reg.add(new_food, EntityType.food);

                    var new_part = reg.create();
                    reg.add(new_part, Spawnable{ .entType = EntityType.snakeBit });
                    reg.add(new_part, EntityType.snakeBit);

                    score.score += 1;
                },
                else => {},
            }
        }
    }
    var end = timer.lap();

    metrics.collisionIterations += 1;
    metrics.collisionTimes.append(end) catch unreachable;
}

fn positionCheckerSystem(reg: *ecs.Registry) void {
    var view = reg.view(.{Position}, .{});

    var eiter = view.entityIterator();
    var iter = view.iterator();
    while (eiter.next()) |entity| {
        if (iter.next()) |position| {
            if (isOutsideScreen(&position)) {
                reg.add(entity, ToClean{ .clean = true });
            }
        }
    }
}

fn cleaningSystem(reg: *ecs.Registry) void {
    var view = reg.view(.{ToClean}, .{});

    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        // std.debug.print("Destroying: {}\n", .{entity});
        reg.destroy(entity);
    }
}

fn spawnSnakeTail(reg: *ecs.Registry) void {
    var group = getSnakeGroup(reg);
    var giter = group.iterator(struct {
        part: *SnakePart,
        position: *Position,
        direction: *Direction,
        animation: *sprites.Animation,
    });

    var tailPos: ?Position = null;
    var tailDir: ?Direction = null;

    while (giter.next()) |entity| {
        tailPos = entity.position.*;
        tailDir = entity.direction.*;

        if (entity.part.* == .tail) {
            entity.part.* = .body;
            entity.animation.* = sprites.body;
        }
    }

    if (tailPos) |tp| {
        if (tailDir) |td| {
            var tailp = tp;
            var taild = td;

            switch (taild) {
                .right => tailp.x -= 1,
                .left => tailp.x += 1,
                .down => tailp.y -= 1,
                .up => tailp.y += 1,
            }

            tailp.fx = @intToFloat(f64, tailp.x);
            tailp.fy = @intToFloat(f64, tailp.y);

            var new_bit = reg.create();
            reg.add(new_bit, EntityType.snakeBit);
            reg.add(new_bit, taild);
            reg.add(new_bit, tailp);
            reg.add(new_bit, Velocity{ .vx = 10, .vy = 10 });
            reg.add(new_bit, SnakePart.tail);
            reg.add(new_bit, sprites.tail);

            snakeIndex += 1;
            reg.add(new_bit, SnakeIndex{ .index = snakeIndex });
        }
    }
}

fn spawnFood(reg: *ecs.Registry) void {
    // var rng = getRng();
    var rng = std.rand.Xoroshiro128.init(@intCast(u64, std.time.milliTimestamp())).random;
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

    var ent = reg.create();
    reg.add(ent, EntityType.food);
    reg.add(ent, Position{ .x = x, .y = y, .fx = fx, .fy = fy });
    reg.add(ent, sprites.food);
}

fn spawningSystem(reg: *ecs.Registry) void {
    var view = reg.view(.{ Spawnable, EntityType }, .{});

    var iter = view.iterator();
    while (iter.next()) |entity| {
        var spawnable = view.get(Spawnable, entity);
        var entType = view.get(EntityType, entity);

        reg.add(entity, ToClean{ .clean = true });

        switch (entType.*) {
            .snakeBit => {
                spawnSnakeTail(reg);
            },
            .food => {
                spawnFood(reg);
            },
            .shot => {},
        }
    }
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    InitWindow(screen_size_x, screen_size_y, "Power Snake");
    sprites.initTexture();

    var reg = ecs.Registry.init(allocator);
    defer reg.deinit();
    {
        var sigletons = &reg.singletons;
        sigletons.add(IsAlive{ .is_alive = true });
        sigletons.add(Score{ .score = 0 });
        sigletons.add(MoveQueue.init(allocator));
        sigletons.add(Rng.init(allocator));

        var head = reg.create();
        reg.add(head, EntityType.snakeBit);
        reg.add(head, Direction.right);
        reg.add(head, Position{ .x = 10, .y = 5, .fx = 10.0, .fy = 5.0 });
        reg.add(head, Velocity{ .vx = 10, .vy = 10 });
        reg.add(head, SnakePart.head);
        reg.add(head, sprites.head);
        reg.add(head, SnakeIndex{ .index = snakeIndex });

        const f = reg.create();
        reg.add(f, EntityType.food);
        reg.add(f, Position{ .x = 25, .y = 10, .fx = 25.0, .fy = 5.0 });
        reg.add(f, sprites.food);
    }

    const fps = 10.0;
    // SetTargetFPS(fps);
    var delta_time: f64 = (1.0 / fps) * 1000.0;

    var previous = @intToFloat(f64, std.time.milliTimestamp());
    var lag: f64 = 0.0;

    while (!WindowShouldClose()) {
        const current = @intToFloat(f64, std.time.milliTimestamp());
        const elapsed = current - previous;

        previous = current;
        lag += elapsed;

        var is_alive = reg.singletons.get(IsAlive).is_alive;

        while (lag >= delta_time) {
            const dt = delta_time * 0.001;

            inputSystem(&reg);

            //directionSystem(&reg);
            moveSystem(&reg, dt);

            collisionSystem(&reg);

            positionCheckerSystem(&reg);
            spawningSystem(&reg);

            cleaningSystem(&reg);
            lag -= delta_time;
        }

        renderSystem(&reg);

        metrics.avg();
    }

    CloseWindow(); // Close window and OpenGL context
}
