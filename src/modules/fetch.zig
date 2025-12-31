const std = @import("std");

pub fn post_audio(allocator: std.mem.Allocator, audio_data: []const u8) !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    const client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response_storage = std.ArrayList(u8).init(allocator);
    defer response_storage.deinit();

    const options = std.http.Client.FetchOptions{
        .location = .{ .url = "" },
        .method = .post,
        .payload = audio_data,
        .headers = .{
            .content_type = .{ .override = "audio/l24" }, // Raw 24-bit PCM
        },
        .response_writer = response_storage.writer,
    };
    const response = try client.fetch(options);

    if (response.status.class() == .success) {
        std.debug.print("Response body:\n{s}\n", .{response_storage.items});
    } else {
        std.debug.print("Request failed: {?s}\n", .{response.status.phrase()});
    }
}
