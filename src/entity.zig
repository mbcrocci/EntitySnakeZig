usingnamespace @import("components.zig");

var entity_index: i64 = 0;

fn newEntityIndex() i64 {
    entity_index += 1;
    return entity_index;
}

pub const Entity = struct {
    index: i64,
    position: Position,
    direction: Direction,
    speed: i64,

    pub fn new(position: Position, direction: Direction) Entity {
        return Entity{
            .index = newEntityIndex(),
            .position = position,
            .direction = direction,
            .speed = 1,
        };
    }
};
