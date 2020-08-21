const std = @import("std");
const ArrayList = std.ArrayList;
const timestamp = std.time.timestamp;
const Xoroshiro128 = std.rand.Xoroshiro128;
const Allocator = std.mem.Allocator;

pub const EntityType = enum {
    snakeBit, food, shot
};

pub const EntRect = @import("raylib").Rectangle;

pub const Position = struct {
    x: i64,
    y: i64,
    fx: f64,
    fy: f64,
};

pub const Direction = enum {
    right, left, up, down
};

pub const Velocity = struct {
    vx: f64, vy: f64
};

pub const SnakePart = enum {
    head, body, tail
};

pub const SnakeIndex = struct {
    index: c_int,
};

pub const ToClean = struct {
    clean: bool
};

pub const PowerUpTag = enum {
    ScoreMultiplier,
    Invulnerable,
    Gun,
};

pub const PowerUp = union(PowerUpTag) {
    ScoreMultiplier: i32,
    Invulnerable,
    Gun,
};

pub const TimedPowerUp = struct {
    power_up: PowerUp,
    added_timestamp: i64,
    duration: i64,

    pub fn shouldRemove(self: *const TimedPowerUp) bool {
        const now = timestamp();

        return now - self.added_timestamp > self.duration;
    }
};

pub const Spawnable = struct {
    entType: EntityType,
};

pub const CollisionType = enum {
    snakeSelf, snakeFood, shotSnake, shotFood
};

// Singleton Components

pub const Score = struct {
    score: i64
};

pub const IsAlive = struct {
    is_alive: bool
};

pub const MoveQueue = struct {
    moves: ArrayList(Direction),
    lastMove: ?Direction,

    pub fn init(allocator: *Allocator) MoveQueue {
        return MoveQueue{
            .moves = ArrayList(Direction).init(allocator),
            .lastMove = null,
        };
    }

    pub fn append(self: *MoveQueue, dir: Direction) void {
        self.moves.append(dir) catch |err| {
            return;
        };
    }

    pub fn pop(self: *MoveQueue) ?Direction {
        var dir = self.moves.popOrNull();

        if (dir) |d| {
            self.lastMove = dir;
        }

        return dir;
    }

    pub fn peek(self: *MoveQueue) ?Direction {
        return self.lastMove;
    }
};

pub const Rng = struct {
    rng: Xoroshiro128,

    pub fn init(allocator: *Allocator) Rng {
        var now = std.time.nanoTimestamp();
        var seed = @intCast(u64, now);

        return Rng{
            .rng = Xoroshiro128.init(seed),
        };
    }
};
