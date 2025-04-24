const std = @import("std");
const builtin = @import("builtin");
const lib = @import("root.zig");
const style = @import("style.zig");
const c = @cImport(@cInclude("time.h"));

const Config = struct {
    seconds: bool = false,
    military: bool = false,
    date: bool = false,
    color: ?std.io.tty.Color = null,
    style: *const [11][5][]const u8 = &style.default,
    x: ?usize = null,
    y: ?usize = null,
    time_fmt: [*c]const u8 = undefined,
    date_fmt: [*c]const u8 = "%A, %d %B",
};

pub fn main() !void {
    var config = Config{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buf: [64]u8 = undefined;
    const stdout = std.io.getStdOut();

    // Parse command-line args
    var iter = try std.process.argsWithAllocator(gpa.allocator());
    defer iter.deinit();
    _ = iter.skip();
    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--seconds")) {
            config.seconds = true;
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--military")) {
            config.military = true;
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--date")) {
            config.date = true;
        } else if (std.mem.startsWith(u8, arg, "--fmt=")) {
            config.date_fmt = arg["--fmt=".len..];
        } else if (std.mem.startsWith(u8, arg, "--color=")) {
            config.color = std.meta.stringToEnum(std.io.tty.Color, arg["--color=".len..]);
        } else if (std.mem.startsWith(u8, arg, "--style=")) {
            if (std.mem.eql(u8, arg["--style=".len..], "line")) {
                config.style = &style.line;
            }
        } else if (std.mem.startsWith(u8, arg, "--x=")) {
            config.x = try std.fmt.parseUnsigned(usize, arg["--x=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--y=")) {
            config.y = try std.fmt.parseUnsigned(usize, arg["--y=".len..], 10);
        } else if (std.mem.eql(u8, arg, "--help")) {
            try printHelp(stdout);
            return;
        } else if (std.mem.eql(u8, arg, "--version")) {
            try stdout.writeAll("zclock: 0.1.0\n(compiled with zig: " ++ builtin.zig_version_string ++ ")\n");
            return;
        }
    }

    // Set the time format according to config
    config.time_fmt = blk: {
        if (config.military) {
            break :blk if (config.seconds) "%T" else "%R";
        } else {
            break :blk if (config.seconds) "%I:%M:%S" else "%I:%M";
        }
    };

    // Set windows terminal encoding to UTF-8
    if (builtin.os.tag == .windows) _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);

    if (config.color) |color| try std.io.tty.detectConfig(stdout).setColor(stdout.writer(), color);
    try stdout.writeAll(lib.ESC.CURSOR_HIDE);
    while (true) {
        const localtime = c.localtime(&c.time(null)).*;
        const time_fmt = fmtTime(&buf, &localtime, config.time_fmt);
        const size = lib.getTerminalSize(stdout.handle);
        try stdout.writeAll(lib.ESC.ERASE_ENTIRE ++ lib.ESC.CURSOR_HOME);
        // Check if there is enough space to render
        if (size.cols < (if (config.seconds) @as(u16, 70) else @as(u16, 46)) or size.rows < (if (config.date) @as(u16, 9) else @as(u16, 7))) {
            try stdout.writer().print("warn: terminal too small\nminimum: {}c x {}r\ncurrent: {}c x {}r", .{
                if (config.seconds) @as(u16, 70) else @as(u16, 46),
                if (config.date) @as(u16, 9) else @as(u16, 7),
                size.cols,
                size.rows,
            });
        } else {
            // Render the clock
            try stdout.writer().writeByteNTimes('\n', config.y orelse size.rows / 2 - 2 - @intFromBool(config.date));
            for (0..5) |h| {
                try stdout.writer().writeByteNTimes(' ', config.x orelse if (config.seconds) size.cols / 2 - 33 else size.cols / 2 - 21);
                for (time_fmt) |digit| {
                    try stdout.writer().print("{s}  ", .{config.style[digit - '0'][h]});
                }
                try stdout.writeAll("\n");
            }
            if (config.date) {
                const date_fmt = fmtTime(&buf, &localtime, config.date_fmt);
                try stdout.writeAll("\n");
                try stdout.writer().writeByteNTimes(' ', config.x orelse size.cols / 2 - date_fmt.len / 2);
                try stdout.writeAll(date_fmt);
            }
        }
        std.Thread.sleep(std.time.ns_per_s);
    }
}

fn printHelp(out: std.fs.File) !void {
    try out.writeAll(
        \\A minimal terminal digital clock.
        \\
        \\Usage:
        \\  zclock <options>
        \\
        \\Options:
        \\  -s, --seconds           Display seconds for the clock.
        \\  -m, --military          Switch to 24-hour time.
        \\  -d, --date              Display the date row below time.
        \\  --fmt=<FORMAT>          Custom strftime formatting for date row.
        \\  --color=<NAME>          A named color e.g. green, red, etc.
        \\  --style=<STYLE>         Supported styles are default, line.
        \\  --x=<X>                 Position clock at given x-axis (cols).
        \\  --y=<Y>                 Position clock at given y-axis (rows).
        \\  --help                  Print this help menu.
        \\  --version               Print the version number.
        \\
    );
}

fn fmtTime(buf: [*c]u8, time: *const c.struct_tm, fmt_string: [*c]const u8) []u8 {
    const len = c.strftime(buf, 64, fmt_string, time);
    return buf[0..len];
}
