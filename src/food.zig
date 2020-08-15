usingnamespace @import("raylib");
usingnamespace @import("entity.zig");
usingnamespace @import("components.zig");
const grid_cell_size = @import("main.zig").grid_cell_size;
const sprites = @import("sprite.zig");
const pu = @import("powerup.zig");

pub const Food = struct {
    entity: Entity,
    power_up: ?pu.PowerUpTag,

    fn rect(self: *Food) Rectangle {
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

    pub fn render(self: *Food) void {
        const s = sprites.food;
        const r = self.rect();

        DrawTexturePro(s.texture.*, s.sourceRect, r, .{
            .x = 0,
            .y = 0,
        }, 0, WHITE);
    }
};
