const std = @import("std");
const Allocator = std.mem.Allocator;
const win32base = @import("win32");
const win32 = struct {
    usingnamespace win32base.ui.input.keyboard_and_mouse;
    usingnamespace win32base.ui.windows_and_messaging;
    usingnamespace win32base.system.windows_sync;
    usingnamespace win32base.foundation;
};

const log = std.log;

const max_inactive_time_ns = 6_000_000_000 * 3;
const tick_rate_ns = 1_000_000;
var accumulated_time_ns: u64 = 0;
var win_width: c_int = 0;
var win_height: c_int = 0;
var party_mode_point: win32.POINT = .{
    .x = 0,
    .y = 0,
};
const party_mode_cycle = 100_000_000.0;
const party_mode_radius = 560.0;

fn calcStep() f64 {
    return @intToFloat(f64, accumulated_time_ns - max_inactive_time_ns) / party_mode_cycle;
}

fn calcPartyModePosition(t: f64) win32.POINT {
    const center_x = @divFloor(win_width, 2);
    const center_y = @divFloor(win_height, 2);
    const offset_x = std.math.cos(t) * party_mode_radius;
    const offset_y = std.math.sin(t) * party_mode_radius;
    return .{
        .x = center_x + @floatToInt(c_int, offset_x),
        .y = center_y + @floatToInt(c_int, offset_y),
    };
}

pub fn main() anyerror!void {
    win_width = win32.GetSystemMetrics(win32.SM_CXSCREEN);
    win_height = win32.GetSystemMetrics(win32.SM_CYSCREEN);
    log.info("{}x{}", .{ win_width, win_height });

    var last_point: win32.POINT = .{
        .x = 0,
        .y = 0,
    };

    var party_mode = false;
    while (true) {
        var current_point: win32.POINT = undefined;
        const current_cursor_pos_result = win32.GetCursorPos(&current_point);
        if (current_cursor_pos_result == 0) {
            log.err("WinAPI failure: {}", .{current_cursor_pos_result});
            log.err(":{}", .{std.os.windows.kernel32.GetLastError()});
            return;
        }

        if (party_mode) {
            const t = calcStep();
            const should_be = calcPartyModePosition(t);
            if (!std.meta.eql(current_point, should_be)) {
                accumulated_time_ns = 0;
                party_mode = false;
            }
        }

        std.time.sleep(tick_rate_ns);

        if (std.meta.eql(last_point, current_point)) {
            accumulated_time_ns += tick_rate_ns;
        } else {
            accumulated_time_ns = 0;
        }

        //log.info("acc: {}", .{accumulated_time_ns});
        if (accumulated_time_ns >= max_inactive_time_ns or party_mode) {
            party_mode = true;
        } else {
            party_mode = false;
        }

        if (party_mode) {
            const t = calcStep();
            last_point = calcPartyModePosition(t);
            _ = win32.SetCursorPos(last_point.x, last_point.y);
        } else {
            last_point = current_point;
        }
    }
}
