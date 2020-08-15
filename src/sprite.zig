usingnamespace @import("raylib");

var texture: Texture = undefined;

pub fn initTexture() void {
    texture = LoadTexture("assets/Textures.png");
}

pub const Animation = struct {
    texture: *Texture,
    sourceRect: Rectangle,
};

pub const grass = Animation{
    .texture = &texture,
    .sourceRect = .{
        .x = 1536,
        .y = 384,
        .width = 384,
        .height = 384,
    },
};

pub const head = Animation{
    .texture = &texture,
    .sourceRect = .{
        .x = 768,
        .y = 0,
        .width = 384,
        .height = 384,
    },
};

pub const body = Animation{
    .texture = &texture,
    .sourceRect = .{
        .x = 384,
        .y = 0,
        .width = 384,
        .height = 384,
    },
};

pub const tail = Animation{
    .texture = &texture,
    .sourceRect = .{
        .x = 0,
        .y = 0,
        .width = 384,
        .height = 384,
    },
};

pub const food = Animation{
    .texture = &texture,
    .sourceRect = .{
        .x = 1152,
        .y = 0,
        .width = 384,
        .height = 384,
    },
};
