const std = @import("std");
const builtin = @import("builtin");
const lib = @import("root.zig");
const digits = @import("digits.zig").default;

const Mode = enum { clock, timer, stopwatch };

const Config = struct {
    seconds: bool = false,
    color: ?std.io.tty.Color = null,
    mode: Mode = .clock,
    military: bool = false,
};

pub fn main() !void {
    var config = Config{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const stdout = std.io.getStdOut();

    // Parse command-line args
    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();
    _ = iter.skip();
    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--seconds")) {
            config.seconds = true;
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--military")) {
            config.military = true;
        } else if (std.mem.startsWith(u8, arg, "--color=")) {
            config.color = std.meta.stringToEnum(std.io.tty.Color, arg["--color=".len..]);
        } else if (std.mem.eql(u8, arg, "--help")) {
            try printHelp(stdout);
            return;
        } else if (std.mem.eql(u8, arg, "--version")) {
            try stdout.writeAll("zclock: 0.1.0\nzig: " ++ builtin.zig_version_string ++ "\n");
            return;
        } else {
            config.mode = std.meta.stringToEnum(Mode, arg) orelse .clock;
        }
    }
    // Set windows terminal encoding to UTF-8
    if (builtin.os.tag == .windows) _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);

    if (config.color) |c| try std.io.tty.detectConfig(stdout).setColor(stdout.writer(), c);
    try stdout.writeAll(lib.ESC.CURSOR_HIDE);
    while (true) {
        try stdout.writeAll(lib.ESC.ERASE_ENTIRE ++ lib.ESC.CURSOR_HOME);
        const t = std.time.epoch.EpochSeconds{ .secs = @intCast(std.time.timestamp() + 19800) };
        const time_fmt = blk: {
            if (config.seconds) {
                break :blk try std.fmt.allocPrint(allocator, "{:0>2}:{:0>2}:{:0>2}", .{
                    if (config.military) t.getDaySeconds().getHoursIntoDay() else t.getDaySeconds().getHoursIntoDay() - 12,
                    t.getDaySeconds().getMinutesIntoHour(),
                    t.getDaySeconds().getSecondsIntoMinute(),
                });
            } else {
                break :blk try std.fmt.allocPrint(allocator, "{:0>2}:{:0>2}", .{
                    if (config.military) t.getDaySeconds().getHoursIntoDay() else t.getDaySeconds().getHoursIntoDay() - 12,
                    t.getDaySeconds().getMinutesIntoHour(),
                });
            }
        };
        defer allocator.free(time_fmt);
        const size = lib.getTerminalSize(stdout.handle);
        // Render the clock
        try stdout.writer().writeByteNTimes('\n', size.rows / 2 - 3);
        for (0..5) |h| {
            try stdout.writer().writeByteNTimes(' ', if (config.seconds) size.cols / 2 - 33 else size.cols / 2 - 21);
            for (time_fmt) |digit| {
                try stdout.writer().print("{s}  ", .{digits[digit - '0'][h]});
            }
            _ = try stdout.writer().writeByte('\n');
        }
        std.Thread.sleep(std.time.ns_per_s);
    }
}

fn printHelp(out: std.fs.File) !void {
    try out.writeAll(
        \\A minimal terminal based digital clock, timer and stopwatch.
        \\
        \\Usage:
        \\  zclock <options>
        \\  zclock [mode] <options>
        \\
        \\Options:
        \\  -s, --seconds          Display seconds for the clock.
        \\  -m, --military         Switch to 24-hour time.
        \\  --color=<value>        A named color e.g. green, red, etc.
        \\  --version              Print the version number.
        \\  --help                 Print this help menu.
        \\
    );
}
