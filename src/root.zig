const std = @import("std");
const builtin = @import("builtin");

pub fn getTerminalSize(fd: std.fs.File.Handle) struct { rows: u16, cols: u16 } {
    switch (builtin.os.tag) {
        .windows => {
            var info: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            _ = std.os.windows.kernel32.GetConsoleScreenBufferInfo(fd, &info);
            return .{
                .rows = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
                .cols = @intCast(info.dwSize.X),
            };
        },
        else => {
            var winsize: std.posix.winsize = undefined;
            _ = std.posix.system.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&winsize));
            return .{
                .rows = winsize.row,
                .cols = winsize.col,
            };
        },
    }
}

/// Terminal escape sequences
pub const ESC = struct {
    pub const ERASE_ENTIRE = "\x1B[2J";
    pub const CURSOR_HOME = "\x1B[H";
    pub const CURSOR_HIDE = "\x1B[?25l";
};
