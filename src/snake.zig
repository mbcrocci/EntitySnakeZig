usingnamespace @import("raylib");
usingnamespace @import("entity.zig");
usingnamespace @import("components.zig");

const grid_cell_size = @import("main.zig").grid_cell_size;
const sprites = @import("sprite.zig");
const std = @import("std");

pub const SnakeBit = struct {
    entity: Entity,
    body_part: SnakePart,

    fn sprite(self: *SnakeBit) sprites.Animation {
        return switch (self.body_part) {
            .head => sprites.head,
            .body => sprites.body,
            .tail => sprites.tail,
        };
    }

    pub fn rect(self: *SnakeBit) Rectangle {
        const fx = @intToFloat(f32, self.entity.position.x);
        const fy = @intToFloat(f32, self.entity.position.y);
        const fgrid = @intToFloat(f32, grid_cell_size);

        return .{
            .x = fx * fgrid,
            .y = fy * fgrid,
            .width = fgrid,
            .height = fgrid,
        };
    }

    pub fn render(self: *SnakeBit) void {
        const fgrid = @intToFloat(f32, grid_cell_size);
        const s = self.sprite();
        const r = self.rect();

        const angle: f64 = switch (self.entity.direction) {
            .right => 0.0,
            .down => 90.0,
            .left => 180.0,
            .up => 270.0,
        };

        DrawTexturePro(s.texture.*, s.sourceRect, r, // Quadradro da imagem
            .{ // origin
            .x = 0,
            .y = 0,
        }, 0, // angulo de totacao
            WHITE);
    }

    pub fn debugRender(self: *SnakeBit) void {
        const s = self.sprite();
        const r = self.rect();
        DrawRectangleLinesEx(r, 2, WHITE);

        const fgrid = @intToFloat(f32, grid_cell_size);

        if (self.body_part == .head) {
            const debug_line: Vector2 = switch (self.entity.direction) {
                .right => .{ .x = r.x + 100, .y = r.y + fgrid / 2 },
                .down => .{ .x = r.x + fgrid / 2, .y = r.y + 100 },
                .left => .{ .x = r.x - 100, .y = r.y + fgrid / 2 },
                .up => .{ .x = r.x + fgrid / 2, .y = r.y - 100 },
            };
            DrawLineEx(
                .{
                    .x = r.x + fgrid / 2,
                    .y = r.y + fgrid / 2,
                },
                debug_line,
                2,
                WHITE,
            );
        }
    }
};
