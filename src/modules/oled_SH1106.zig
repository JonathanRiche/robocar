// fn set_text() void {}

pub fn center_to_screen(buf: []u8, str: []u8, empty_row: []const u8, four_rows: []const u8) []u8 {
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
