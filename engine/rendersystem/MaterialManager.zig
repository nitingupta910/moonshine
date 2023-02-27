const std = @import("std");
const vk = @import("vulkan");

const VulkanContext = @import("./VulkanContext.zig");
const Commands = @import("./Commands.zig");
const VkAllocator = @import("./Allocator.zig");
const ImageManager = @import("./ImageManager.zig");

const vector = @import("../vector.zig");

pub const MaterialType = enum(c_int) {
    standard_pbr,
};

pub const Material = extern struct {
    // all materials have normal and emissive
    normal: u32,
    emissive: u32,

    // then each material has specific type which influences fields below
    type: MaterialType = .standard_pbr,

    // TBD specifics
    color: u32,
    metalness: u32,
    roughness: u32,
    ior: f32 = 1.5,
};

textures: ImageManager,
materials: VkAllocator.DeviceBuffer, // StandardPBR

const Self = @This();

pub fn create(vc: *const VulkanContext, vk_allocator: *VkAllocator, allocator: std.mem.Allocator, commands: *Commands, texture_sources: []const ImageManager.TextureSource, materials: []const Material) !Self {
    var textures = try ImageManager.createTexture(vc, vk_allocator, allocator, texture_sources, commands);
    errdefer textures.destroy(vc, allocator);

    const materials_tmp = try vk_allocator.createHostBuffer(vc, Material, @intCast(u32, materials.len), .{ .transfer_src_bit = true });
    defer materials_tmp.destroy(vc);
    std.mem.copy(Material, materials_tmp.data, materials);

    const materials_gpu = try vk_allocator.createDeviceBuffer(vc, allocator, @sizeOf(Material) * materials.len, .{ .storage_buffer_bit = true, .transfer_dst_bit = true });
    errdefer materials_gpu.destroy(vc);
    
    try commands.startRecording(vc);
    commands.recordUploadBuffer(Material, vc, materials_gpu, materials_tmp);
    try commands.submitAndIdleUntilDone(vc);

    return Self {
        .textures = textures,
        .materials = materials_gpu,
    };
}

pub fn destroy(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator) void {
    self.textures.destroy(vc, allocator);
    self.materials.destroy(vc);
}
