const std = @import("std");
const vk = @import("vulkan");

const VulkanContext = @import("./VulkanContext.zig");
const VkAllocator = @import("./Allocator.zig");
const Window = @import("../Window.zig");
const Swapchain = @import("./Swapchain.zig");
const ImageManager = @import("./ImageManager.zig");
const Commands = @import("./Commands.zig");
const DescriptorLayout = @import("./descriptor.zig").OutputDescriptorLayout;
const DestructionQueue = @import("./DestructionQueue.zig");
const utils = @import("./utils.zig");

const measure_perf = @import("build_options").vk_measure_perf;

pub fn Display(comptime num_frames: comptime_int) type {
    return struct {
        const Self = @This();

        frames: [num_frames]Frame,
        frame_index: u8,

        swapchain: Swapchain,

        destruction_queue: DestructionQueue,

        // uses initial_extent as the render extent -- that is, the buffer that is actually being rendered into, irrespective of window size
        // then during rendering the render buffer is blitted into the swapchain images
        pub fn create(vc: *const VulkanContext, initial_extent: vk.Extent2D) !Self {
            var swapchain = try Swapchain.create(vc, initial_extent);
            errdefer swapchain.destroy(vc);

            var frames: [num_frames]Frame = undefined;
            comptime var i = 0;
            inline while (i < num_frames) : (i += 1) {
                frames[i] = try Frame.create(vc);
            }

            return Self {
                .swapchain = swapchain,
                .frames = frames,
                .frame_index = 0,

                .destruction_queue = DestructionQueue.create(), // TODO: need to clean this every once in a while since we're only allowed a limited amount of most types of handles
            };
        }

        pub fn destroy(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator) void {
            self.swapchain.destroy(vc);
            comptime var i = 0;
            inline while (i < num_frames) : (i += 1) {
                self.frames[i].destroy(vc);
            }
            self.destruction_queue.destroy(vc, allocator);
        }

        pub fn startFrame(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator, window: *const Window) !vk.CommandBuffer {
            const frame = self.frames[self.frame_index];

            _ = try vc.device.waitForFences(1, @ptrCast([*]const vk.Fence, &frame.fence), vk.TRUE, std.math.maxInt(u64));
            try vc.device.resetFences(1, @ptrCast([*]const vk.Fence, &frame.fence));

            if (measure_perf) {
                var timestamps: [2]u64 = undefined;
                const result = try vc.device.getQueryPoolResults(frame.query_pool, 0, 2, 2 * @sizeOf(u64), &timestamps, @sizeOf(u64), .{.@"64_bit" = true });
                const time = (@intToFloat(f64, timestamps[1] - timestamps[0]) * vc.physical_device.properties.limits.timestamp_period) / 1_000_000.0;
                std.debug.print("{}: {d}ms\n", .{result, time});
                vc.device.resetQueryPool(frame.query_pool, 0, 2);
            }

            // we can optionally handle swapchain recreation on suboptimal here,
            // but I think for some reason it's better to just do it after presentation
            while (true) {
                if (self.swapchain.acquireNextImage(vc, frame.image_acquired)) |_| break else |err| switch (err) {
                    error.OutOfDateKHR => try self.recreate(vc, allocator, window),
                    else => return err,
                }
            }

            try vc.device.resetCommandPool(frame.command_pool, .{});
            try vc.device.beginCommandBuffer(frame.command_buffer, &.{
                .flags = .{ .one_time_submit_bit = true },
                .p_inheritance_info = null,
            });

            if (measure_perf) vc.device.cmdWriteTimestamp2(frame.command_buffer, .{ .top_of_pipe_bit = true }, frame.query_pool, 0);

            return frame.command_buffer;
        }

        pub fn recreate(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator, window: *const Window) !void {
            try self.destruction_queue.add(allocator, self.swapchain);
            try self.swapchain.recreate(vc, window.getExtent());
        }

        pub fn endFrame(self: *Self, vc: *const VulkanContext, allocator: std.mem.Allocator, window: *const Window) !void {
            const frame = self.frames[self.frame_index];

            if (measure_perf) vc.device.cmdWriteTimestamp2(frame.command_buffer, .{ .bottom_of_pipe_bit = true }, frame.query_pool, 1);

            try vc.device.endCommandBuffer(frame.command_buffer);

            try vc.device.queueSubmit2(vc.queue, 1, &[_]vk.SubmitInfo2 { .{
                .flags = .{},
                .wait_semaphore_info_count = 1,
                .p_wait_semaphore_infos = utils.toPointerType(&vk.SemaphoreSubmitInfoKHR{
                    .semaphore = frame.image_acquired,
                    .value = 0,
                    .stage_mask = .{ .color_attachment_output_bit = true },
                    .device_index = 0,
                }),
                .command_buffer_info_count = 1,
                .p_command_buffer_infos = utils.toPointerType(&vk.CommandBufferSubmitInfo {
                    .command_buffer = frame.command_buffer,
                    .device_mask = 0,
                }),
                .signal_semaphore_info_count = 1,
                .p_signal_semaphore_infos = utils.toPointerType(&vk.SemaphoreSubmitInfoKHR {
                    .semaphore = frame.command_completed,
                    .value = 0,
                    .stage_mask =  .{ .color_attachment_output_bit = true },
                    .device_index = 0,
                }),
            }}, frame.fence);

            if (self.swapchain.present(vc, vc.queue, frame.command_completed)) |ok| {
                if (ok == vk.Result.suboptimal_khr) {
                    try self.recreate(vc, allocator, window);
                }
            } else |err| {
                if (err == error.OutOfDateKHR) {
                    try self.recreate(vc, allocator, window);
                }
                return err;
            }

            self.frame_index = (self.frame_index + 1) % num_frames;
        }

        const Frame = struct {
            image_acquired: vk.Semaphore,
            command_completed: vk.Semaphore,
            fence: vk.Fence,

            command_pool: vk.CommandPool,
            command_buffer: vk.CommandBuffer,

            query_pool: if (measure_perf) vk.QueryPool else void,

            fn create(vc: *const VulkanContext) !Frame {
                const image_acquired = try vc.device.createSemaphore(&.{}, null);
                errdefer vc.device.destroySemaphore(image_acquired, null);

                const command_completed = try vc.device.createSemaphore(&.{}, null);
                errdefer vc.device.destroySemaphore(command_completed, null);

                const fence = try vc.device.createFence(&.{
                    .flags = .{ .signaled_bit = true },
                }, null);

                const command_pool = try vc.device.createCommandPool(&.{
                    .queue_family_index = vc.physical_device.queue_family_index,
                    .flags = .{ .transient_bit = true },
                }, null);
                errdefer vc.device.destroyCommandPool(command_pool, null);

                var command_buffer: vk.CommandBuffer = undefined;
                try vc.device.allocateCommandBuffers(&.{
                    .level = vk.CommandBufferLevel.primary,
                    .command_pool = command_pool,
                    .command_buffer_count = 1,
                }, @ptrCast([*]vk.CommandBuffer, &command_buffer));

                const query_pool = if (measure_perf) try vc.device.createQueryPool(&.{
                    .query_type = .timestamp,
                    .query_count = 2,
                }, null) else undefined;
                errdefer if (measure_perf) vc.device.destroyQueryPool(query_pool, null);
                if (measure_perf) vc.device.resetQueryPool(query_pool, 0, 2);

                return Frame {
                    .image_acquired = image_acquired,
                    .command_completed = command_completed,
                    .fence = fence,

                    .command_pool = command_pool,
                    .command_buffer = command_buffer,

                    .query_pool = query_pool,
                };
            }

            fn destroy(self: *Frame, vc: *const VulkanContext) void {
                vc.device.destroySemaphore(self.image_acquired, null);
                vc.device.destroySemaphore(self.command_completed, null);
                vc.device.destroyFence(self.fence, null);
                vc.device.destroyCommandPool(self.command_pool, null);
                if (measure_perf) vc.device.destroyQueryPool(self.query_pool, null);
            }
        };
    };
}
