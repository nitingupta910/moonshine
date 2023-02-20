const std = @import("std");

const Engine = @import("engine").rendersystem.Engine;
const ObjectPicker = @import("engine").ObjectPicker;
const Window = @import("engine").Window;
const Camera = @import("engine").rendersystem.Camera;

const vector = @import("engine").vector;
const F32x3 = vector.Vec3(f32);
const F32x2 = vector.Vec2(f32);
const Mat4 = vector.Mat4(f32);
const Mat3x4 = vector.Mat3x4(f32);
const Vec3 = vector.Vec3(f32);

const ChessSet = @import("./ChessSet.zig");
const Coord = @import("./coord.zig").Coord;

const initial_aspect = .{ 16, 10 };
const initial_height = 600;
const initial_width = initial_height * initial_aspect[0] / initial_aspect[1];

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const textures = [_]ChessSet.Texture {
        .{
            .dds_filepath = "./assets/textures/board/color.dds",
        },
        .{
            .f32x1 = 0.4,
        },
        .{
            .f32x1 = 0.3,
        },
        .{
            .dds_filepath = "./assets/textures/board/normal.dds",
        },
        .{
            .f32x3 = F32x3.new(0.653, 0.653, 0.653),
        },
        .{
            .f32x1 = 0.2,
        },
        .{
            .f32x1 = 0.15,
        },
        .{
            .f32x2 = F32x2.new(0.5, 0.5),
        },
        .{
            .f32x3 = F32x3.new(0.0004, 0.0025, 0.0096),
        },
        .{
            .f32x3 = F32x3.new(0.901, 0.722, 0.271),
        },
        .{
            .f32x1 = 0.6,
        },
        .{
            .f32x1 = 0.05,
        },
        .{
            .f32x3 = F32x3.new(0.0, 0.0, 0.0),
        },
    };

    const materials = comptime [_]ChessSet.Material {
        ChessSet.Material {
            .color = 0,
            .metalness = 1,
            .roughness = 2,
            .normal = 3,
            .emissive = 12,
        },
        ChessSet.Material {
            .color = 4,
            .metalness = 5,
            .roughness = 6,
            .normal = 7,
            .emissive = 12,
        },
        ChessSet.Material {
            .color = 8,
            .metalness = 5,
            .roughness = 6,
            .normal = 7,
            .emissive = 12,
        },
        ChessSet.Material {
            .color = 9,
            .metalness = 10,
            .roughness = 11,
            .normal = 7,
            .emissive = 12,
        },
    };

    const window = try Window.create(initial_width, initial_height, "rtchess");
    defer window.destroy();

    var engine = try Engine.create(allocator, &window, "rtchess");
    defer engine.destroy(allocator);

    const set_info = ChessSet.SetInfo {
        .board = .{
            .material_idx = 0,
            .model_path = "./assets/models/board.obj"
        },
        .pawn = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/pawn.obj"
        },
        .rook = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/rook.obj"
        },
        .knight = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/knight.obj"
        },
        .bishop = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/bishop.obj"
        },
        .king = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/king.obj"
        },
        .queen = .{
            .white_material_idx = 1,
            .black_material_idx = 2,
            .model_path = "./assets/models/queen.obj"
        },
    };

    // TODO: unhardcode skybox
    var set = try ChessSet.create(&engine.context, &engine.allocator, allocator, &engine.commands, &textures, &materials, "assets/wide_street_1k.exr", set_info, &engine.world_descriptor_layout, &engine.background_descriptor_layout);
    defer set.destroy(&engine.context, allocator);

    var object_picker = try ObjectPicker.create(&engine.context, &engine.allocator, allocator, engine.world_descriptor_layout, &engine.commands);
    defer object_picker.destroy(&engine.context);

    var window_data = WindowData {
        .engine = &engine,
        .set = &set,
        .object_picker = &object_picker,
        .clicked = null,
    };

    window.setAspectRatio(initial_aspect[0], initial_aspect[1]);
    window.setUserPointer(&window_data);
    window.setKeyCallback(keyCallback);
    window.setMouseButtonCallback(mouseButtonCallback);

    var active_piece: ?u16 = null;

    while (!window.shouldClose()) {
        const buffer = try engine.startFrame(&window, allocator);
        engine.setScene(&set.world, &set.background, buffer);
        if (window_data.clicked) |click_data| {
            if (click_data.instance_index > 0) {
                const instance_index = @intCast(u16, click_data.instance_index);
                if (active_piece) |active_piece_index| {
                    if (instance_index == active_piece_index) {
                        active_piece = null;
                    } else {
                        set.world.accel.updateSkin(instance_index, 3);
                        active_piece = instance_index;
                    }
                    if (Color.fromIndex(active_piece_index) == .white) {
                        set.world.accel.updateSkin(instance_index, 1);
                    } else {
                        set.world.accel.updateSkin(instance_index, 2);
                    }
                } else {
                    set.world.accel.updateSkin(instance_index, 3);
                    active_piece = instance_index;
                }
                engine.camera.film.clear();
            } else if (click_data.instance_index == 0 and (click_data.primitive_index == 11 or click_data.primitive_index == 5)) {
                if (active_piece) |active_piece_index| {
                    const barycentrics = F32x3.new(1.0 - click_data.barycentrics.x - click_data.barycentrics.y, click_data.barycentrics.x, click_data.barycentrics.y);

                    var p1: F32x3 = undefined;
                    var p2: F32x3 = undefined;

                    const edge = Coord.board_size / 2.0;
                    if (click_data.primitive_index == 11) {
                        p1 = F32x3.new(-edge, edge, edge);
                        p2 = F32x3.new(-edge, -edge, edge);
                    } else if (click_data.primitive_index == 5) {
                        p1 = F32x3.new(-edge, edge, -edge);
                        p2 = F32x3.new(-edge, edge, edge);
                    }

                    const location = F32x2.new(p1.dot(barycentrics), p2.dot(barycentrics));
                    var transform = Coord.fromLocation(location).toTransform();
                    if (Color.fromIndex(active_piece_index) == .black) {
                        transform = transform.mul(Mat3x4.from_rotation(Vec3.new(0.0, 1.0, 0.0), std.math.pi));
                    }
                    set.move(active_piece_index, transform);
                    engine.camera.film.clear();
                }
            } else if (click_data.instance_index == -1) {
                if (active_piece) |active_piece_index| {
                    set.changeVisibility(active_piece_index, false);
                    active_piece = null;
                    engine.camera.film.clear();
                }
            }
            window_data.clicked = null;
        }
        try set.world.accel.recordChanges(&engine.context, buffer);
        try engine.recordFrame(buffer);
        try engine.endFrame(&window, allocator, buffer);
        window.pollEvents();
    }
    try engine.context.device.deviceWaitIdle();

    std.log.info("Program completed!", .{});
}

pub const Color = enum {
    black,
    white,

    pub fn fromIndex(index: u32) Color {
        if (index < 9 or index == 17 or index == 21 or index == 25 or index == 31 or index == 29 or index == 26 or index == 22 or index == 18) {
            return .white;
        } else {
            return .black;
        }
    }
};

const WindowData = struct {
    engine: *Engine,
    set: *ChessSet,
    object_picker: *ObjectPicker,
    clicked: ?ObjectPicker.ClickData,
};

fn mouseButtonCallback(window: *const Window, button: Window.MouseButton, action: Window.Action) void {
    const ptr = window.getUserPointer().?;
    const window_data = @ptrCast(*WindowData, @alignCast(@alignOf(WindowData), ptr));

    if (button == .left and action == .press) {
        const pos = window.getCursorPos();
        const x = @floatCast(f32, pos.x) / @intToFloat(f32, window_data.engine.display.swapchain.extent.width);
        const y = @floatCast(f32, pos.y) / @intToFloat(f32, window_data.engine.display.swapchain.extent.height);
        window_data.clicked = window_data.object_picker.getClick(&window_data.engine.context, F32x2.new(x, y), window_data.engine.camera, window_data.set.world.descriptor_set) catch unreachable;
    }
}

fn keyCallback(window: *const Window, key: u32, action: Window.Action) void {
    const ptr = window.getUserPointer().?;
    const window_data = @ptrCast(*WindowData, @alignCast(@alignOf(WindowData), ptr));
    const engine = window_data.engine;
    if (action == .repeat or action == .press) {
        if (key == 65 or key == 68 or key == 83 or key == 87) {
            const move_amount = 1.0 / 18.0;
            var mat: Mat4 = undefined;
            if (key == 65) {
                mat = Mat4.fromAxisAngle(F32x3.new(0.0, 1.0, 0.0), -move_amount);
            } else if (key == 68) {
                mat = Mat4.fromAxisAngle(F32x3.new(0.0, 1.0, 0.0), move_amount);
            } else if (key == 83) {
                const target_dir = engine.camera_create_info.origin.sub(engine.camera_create_info.target);
                const axis = engine.camera_create_info.up.cross(target_dir).unit();
                if (F32x3.new(0.0, -1.0, 0.0).dot(target_dir.unit()) > 0.99) {
                    return;
                }
                mat = Mat4.fromAxisAngle(axis, move_amount);
            } else if (key == 87) {
                const target_dir = engine.camera_create_info.origin.sub(engine.camera_create_info.target);
                const axis = engine.camera_create_info.up.cross(target_dir).unit();
                if (F32x3.new(0.0, 1.0, 0.0).dot(target_dir.unit()) > 0.99) {
                    return;
                }
                mat = Mat4.fromAxisAngle(axis, -move_amount);
            } else unreachable;

            engine.camera_create_info.origin = mat.mul_point(engine.camera_create_info.origin.sub(engine.camera_create_info.target)).add(engine.camera_create_info.target);
        } else if (key == 70 and engine.camera_create_info.aperture > 0.0) {
            engine.camera_create_info.aperture -= 0.0005;
        } else if (key == 82) {
            engine.camera_create_info.aperture += 0.0005;
        } else if (key == 81) {
            engine.camera_create_info.focus_distance -= 0.01;
        } else if (key == 69) {
            engine.camera_create_info.focus_distance += 0.01;
        } else return;

        engine.camera.properties = Camera.Properties.new(engine.camera_create_info);
        engine.camera.film.clear();
    }
}
