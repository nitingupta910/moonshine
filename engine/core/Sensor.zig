const std = @import("std");
const vk = @import("vulkan");

const engine = @import("../engine.zig");
const VulkanContext =  engine.core.VulkanContext;
const VkAllocator =  engine.core.Allocator;
const Commands =  engine.core.Commands;

const ImageManager = @import("./ImageManager.zig");
const vk_helpers = @import("./vk_helpers.zig");

// must be kept in sync with shader
pub const DescriptorLayout = @import("./descriptor.zig").DescriptorLayout(&.{
    .{
        .binding = 0,
        .descriptor_type = .storage_image,
        .descriptor_count = 1,
        .stage_flags = .{ .raygen_bit_khr = true },
    }
}, null, "Sensor");

image: ImageManager.Handle,
descriptor_set: vk.DescriptorSet,
extent: vk.Extent2D,
sample_count: u32,

const Self = @This();

pub fn create(vc: *const VulkanContext, allocator: std.mem.Allocator, vk_allocator: *VkAllocator, descriptor_layout: *const DescriptorLayout, images: *ImageManager, extent: vk.Extent2D) !Self {
    const image = try images.appendRawImage(vc, vk_allocator, allocator, extent, .{ .storage_bit = true, .transfer_src_bit = true, }, .r32g32b32a32_sfloat, "sensor");

    const descriptor_set = try descriptor_layout.allocate_set(vc, [_]vk.WriteDescriptorSet {
        vk.WriteDescriptorSet {
            .dst_set = undefined,
            .dst_binding = 0,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .storage_image,
            .p_image_info = @ptrCast(&vk.DescriptorImageInfo {
                .sampler = .null_handle,
                .image_view = images.data.get(image).view,
                .image_layout = .general,
            }),
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        }
    });

    return Self {
        .image = image,
        .descriptor_set = descriptor_set,
        .extent = extent,
        .sample_count = 0,
    };
}

// intended to be used in a loop, e.g
//
// while rendering:
//   recordPrepareForCapture(...)
//   ...
//   recordPrepareForCopy(...)
pub fn recordPrepareForCapture(self: *const Self, vc: *const VulkanContext, images: *const ImageManager, command_buffer: vk.CommandBuffer, capture_stage: vk.PipelineStageFlags2) void {
    vc.device.cmdPipelineBarrier2(command_buffer, &vk.DependencyInfo{
        .image_memory_barrier_count = 1,
        .p_image_memory_barriers = @ptrCast(&vk.ImageMemoryBarrier2{
            .dst_stage_mask = capture_stage,
            .dst_access_mask = if (self.sample_count == 0) .{ .shader_storage_write_bit = true } else .{ .shader_storage_write_bit = true, .shader_storage_read_bit = true },
            .old_layout = if (self.sample_count == 0) .undefined else .transfer_src_optimal,
            .new_layout = .general,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .image = images.data.get(self.image).handle,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = vk.REMAINING_ARRAY_LAYERS,
            },
        }),
    });
}

pub fn recordPrepareForCopy(self: *const Self, vc: *const VulkanContext, images: *const ImageManager, command_buffer: vk.CommandBuffer, capture_stage: vk.PipelineStageFlags2, copy_stage: vk.PipelineStageFlags2) void {
    vc.device.cmdPipelineBarrier2(command_buffer, &vk.DependencyInfo{
        .image_memory_barrier_count = 1,
        .p_image_memory_barriers = @ptrCast(&vk.ImageMemoryBarrier2 {
            .src_stage_mask = capture_stage,
            .src_access_mask = if (self.sample_count == 0) .{ .shader_storage_write_bit = true } else .{ .shader_storage_write_bit = true, .shader_storage_read_bit = true },
            .dst_stage_mask = copy_stage,
            .dst_access_mask = .{ .transfer_read_bit = true },
            .old_layout = .general,
            .new_layout = .transfer_src_optimal,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .image = images.data.get(self.image).handle,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = vk.REMAINING_ARRAY_LAYERS,
            },
        }),
    });
}

pub fn clear(self: *Self) void {
    self.sample_count = 0;
}
