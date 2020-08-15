usingnamespace @import("raylib");
const std = @import("std");

pub const PowerUpTag = enum {
    ScoreMultiplier,
    Invulnerable,
    Gun,
};

pub const PowerUp = union(PowerUpTag) {
    ScoreMultiplier: i32, Invulnerable, Gun
};

pub fn renderPowerup(pu: *PowerUp, x: i32, y: i32) void {
    var pp = pu.*;
    switch (pp) {
        .ScoreMultiplier => |p| {
            var st = FormatText("Score Multiplier: %02i", p);
            DrawText(st, x, y, 24, WHITE);
        },
        .Invulnerable => {
            DrawText("Invulnerable", x, y, 24, WHITE);
        },
        .Gun => {
            DrawText("Gun", x, y, 24, WHITE);
        },
    }
}

pub const TimedPowerUp = struct {
    power_up: PowerUp,
    added_timestamp: i64,
    duration: i64,

    pub fn shouldRemove(self: *const TimedPowerUp) bool {
        const now = std.time.timestamp();

        return now - self.added_timestamp > self.duration;
    }
};
