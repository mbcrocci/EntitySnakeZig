usingnamespace @import("raylib");
usingnamespace @import("entity.zig");
const grid_cell_size = @import("main.zig").grid_cell_size;

pub const Shot = struct {
    hit: bool,
    entity: Entity,

    fn rect(self: *Shot) Rectangle {
        const fx = @intToFloat(f32, self.entity.position.x);
        const fy = @intToFloat(f32, self.entity.position.y);
        const fgrid = @intToFloat(f32, grid_cell_size);

        return .{
            .x = fx * fgrid + (fgrid / 4.0),
            .y = fy * fgrid + (fgrid / 4.0),
            .width = fgrid / 2.0,
            .height = fgrid / 2.0,
        };
    }

    pub fn render(self: *Shot) void {
        const r = self.rect();

        DrawRectangleRec(r, WHITE);
    }

    pub fn move(self: *Shot) void {
        switch (self.entity.direction) {
            .right => self.entity.position.x += self.entity.speed,
            .left => self.entity.position.x -= self.entity.speed,
            .down => self.entity.position.y += self.entity.speed,
            .up => self.entity.position.y -= self.entity.speed,
        }
    }

    pub fn hitEntity(self: *Shot, entity: *Entity) bool {
        const shot_pos = self.entity.position;
        const ent_pos = entity.position;

        var next_shot = self.*;
        next_shot.move();

        const next_pos = next_shot.entity.position;

        return switch (self.entity.direction) {
            .right => {
                return shot_pos.x <= ent_pos.x and
                    ent_pos.x < next_pos.x and
                    shot_pos.y == ent_pos.y;
            },
            .left => {
                return shot_pos.x >= ent_pos.x and
                    ent_pos.x > next_pos.x and
                    next_pos.y == ent_pos.y;
            },
            .down => {
                return shot_pos.x == ent_pos.x and
                    shot_pos.y <= ent_pos.y and
                    ent_pos.y < next_pos.y;
            },
            .up => {
                return shot_pos.x == ent_pos.x and
                    shot_pos.y >= ent_pos.y and
                    ent_pos.y > next_pos.y;
            },
        };
    }
};
