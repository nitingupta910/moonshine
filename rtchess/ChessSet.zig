const std = @import("std");

const VulkanContext = @import("engine").rendersystem.VulkanContext;
const VkAllocator = @import("engine").rendersystem.Allocator;
const Commands = @import("engine").rendersystem.Commands;
const World = @import("engine").rendersystem.World;
const Background = @import("engine").rendersystem.Background;
const descriptor = @import("engine").rendersystem.descriptor;
const WorldDescriptorLayout = descriptor.WorldDescriptorLayout;
const BackgroundDescriptorLayout = descriptor.BackgroundDescriptorLayout;
const vector = @import("engine").vector;
const Mat3x4 = vector.Mat3x4(f32);
const F32x3 = vector.Vec3(f32);
const Coord = @import("./coord.zig").Coord;

pub const Material = World.Material;

pub const Piece = struct {
    black_material_idx: u32,
    white_material_idx: u32,
    model_path: []const u8,
};

pub const Board = struct {
    material_idx: u32,
    model_path: []const u8,
};

pub const SetInfo = struct {
    board: Board,

    pawn: Piece,
    rook: Piece,
    knight: Piece,
    bishop: Piece,
    king: Piece,
    queen: Piece,
};

world: World,
background: Background,

const Self = @This();

pub fn create(vc: *const VulkanContext, vk_allocator: *VkAllocator, allocator: std.mem.Allocator, commands: *Commands, materials: []const Material, background_path: []const u8, chess_set: SetInfo, descriptor_layout: *const WorldDescriptorLayout, background_descriptor_layout: *const BackgroundDescriptorLayout) !Self {

    const mesh_groups = [_]World.MeshGroup {
        .{ // board
            .meshes = &.{ 0 },
        },
        .{ // pawn
            .meshes = &.{ 1 },
        },
        .{ // rook
            .meshes = &.{ 2 },
        },
        .{ // knight
            .meshes = &.{ 3 },
        },
        .{ // bishop
            .meshes = &.{ 4 },
        },
        .{ // king
            .meshes = &.{ 5 },
        },
        .{ // queen
            .meshes = &.{ 6 },
        },
    };

    const instance_count = 33;

    var instances = World.Instances {};
    try instances.ensureTotalCapacity(allocator, instance_count);
    defer instances.deinit(allocator);

    // board
    instances.appendAssumeCapacity(.{
        .transform = Mat3x4.identity,
        .mesh_group = 0,
        .materials = &.{ 0 },
    });

    const black_rotation = Mat3x4.from_rotation(F32x3.new(0.0, 1.0, 0.0), std.math.pi);

    // pawns
    {
        // white
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.h2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.g2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.f2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.e2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.d2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.c2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.b2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.a2.toTransform(),
                .mesh_group = 1,
                .materials = &.{ 1 },
            });
        }
        // black
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.h7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.g7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.f7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.e7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.d7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.c7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.b7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.a7.toTransform().mul(black_rotation),
                .mesh_group = 1,
                .materials = &.{ 2 },
            });
        }
    }

    // rooks
    {
        // white
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.a1.toTransform(),
                .mesh_group = 2,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.h1.toTransform(),
                .mesh_group = 2,
                .materials = &.{ 1 },
            });
        }
        // black
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.a8.toTransform().mul(black_rotation),
                .mesh_group = 2,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.h8.toTransform().mul(black_rotation),
                .mesh_group = 2,
                .materials = &.{ 2 },
            });
        }
    }

    // knights
    {
        // white
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.b1.toTransform(),
                .mesh_group = 3,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.g1.toTransform(),
                .mesh_group = 3,
                .materials = &.{ 1 },
            });
        }
        // black
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.b8.toTransform().mul(black_rotation),
                .mesh_group = 3,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.g8.toTransform().mul(black_rotation),
                .mesh_group = 3,
                .materials = &.{ 2 },
            });
        }
    }

    // bishops
    {
        // white
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.c1.toTransform(),
                .mesh_group = 4,
                .materials = &.{ 1 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.f1.toTransform(),
                .mesh_group = 4,
                .materials = &.{ 1 },
            });
        }
        // black
        {
            instances.appendAssumeCapacity(.{
                .transform = Coord.c8.toTransform().mul(black_rotation),
                .mesh_group = 4,
                .materials = &.{ 2 },
            });
            instances.appendAssumeCapacity(.{
                .transform = Coord.f8.toTransform().mul(black_rotation),
                .mesh_group = 4,
                .materials = &.{ 2 },
            });
        }
    }

    // kings
    {
        // white
        instances.appendAssumeCapacity(.{
            .transform = Coord.e1.toTransform(),
            .mesh_group = 5,
            .materials = &.{ 1 },
        });
        // black
        instances.appendAssumeCapacity(.{
            .transform = Coord.e8.toTransform().mul(black_rotation),
            .mesh_group = 5,
            .materials = &.{ 2 },
        });
    }

    // queens
    {
        // white
        instances.appendAssumeCapacity(.{
            .transform = Coord.d1.toTransform(),
            .mesh_group = 6,
            .materials = &.{ 1 },
        });
        // black
        instances.appendAssumeCapacity(.{
            .transform = Coord.d8.toTransform().mul(black_rotation),
            .mesh_group = 6,
            .materials = &.{ 2 },
        });
    }

    const mesh_filepaths = [_][]const u8 {
        chess_set.board.model_path,
        chess_set.pawn.model_path,
        chess_set.rook.model_path,
        chess_set.knight.model_path,
        chess_set.bishop.model_path,
        chess_set.king.model_path,
        chess_set.queen.model_path,
    };

    const world = try World.create(vc, vk_allocator, allocator, commands, materials, &mesh_filepaths, instances, &mesh_groups, descriptor_layout);
    const background = try Background.create(vc, vk_allocator, allocator, commands, background_descriptor_layout, world.sampler, background_path);

    return Self {
        .world = world,
        .background = background,
    };
}

// todo: make this more high level
pub fn move(self: *Self, index: u32, new_transform: Mat3x4) void {
    self.world.updateTransform(index, new_transform);
}

pub fn changeVisibility(self: *Self, index: u32, visible: bool) void {
    self.world.updateVisibility(index, visible);
}

pub fn destroy(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator) void {
    self.world.destroy(vc, allocator);
    self.background.destroy(vc, allocator);
}
