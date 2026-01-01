const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const font8x8 = @import("font8x8");
const EMPTY_ROW: []const u8 = " " ** 16;
const FOUR_ROWS = EMPTY_ROW ** 4;

const hardware_config = @import("../hardware_config.zig");

const Text_Config = struct { fba: *std.heap.FixedBufferAllocator, lcd: hardware_config.OLED, screen_text: []const u8, default_sleep_time: u32 = 1000 };

pub fn set_text(config: Text_Config) void {
    const lcd = config.lcd;
    const fba = config.fba;
    const screen_text = config.screen_text;

    var aa = std.heap.ArenaAllocator.init(fba.allocator());
    defer aa.deinit();

    var temp_buf: [7]u8 = undefined;
    const str = std.fmt.bufPrint(&temp_buf, "{s}", .{screen_text}) catch "No Text";
    var counter_buf: [80]u8 = undefined;
    const text_centered = center_to_screen(&counter_buf, str, EMPTY_ROW, FOUR_ROWS);

    const text = font8x8.Fonts.drawAlloc(aa.allocator(), text_centered) catch "No Font A";

    lcd.clear_screen(false) catch unreachable;
    lcd.write_gdram(text) catch unreachable;

    time.sleep_ms(config.default_sleep_time);
}

pub fn center_to_screen(buf: []u8, str: []const u8, empty_row: []const u8, four_rows: []const u8) []u8 {
    const ldc_row_len = empty_row.len;
    const four_rows_len = four_rows.len;
    const padding = @divTrunc(ldc_row_len - str.len, 2);

    // Copy the initial four rows
    @memcpy(buf[0..four_rows_len], four_rows);

    // Add left padding
    const left_pad_start = four_rows_len;
    const left_pad_end = left_pad_start + padding;
    @memset(buf[left_pad_start..left_pad_end], ' ');

    // Copy the centered string
    const str_start = left_pad_end;
    const str_end = str_start + str.len;
    @memcpy(buf[str_start..str_end], str);

    // Add right padding
    @memset(buf[str_end..buf.len], ' ');
    return buf;
}
