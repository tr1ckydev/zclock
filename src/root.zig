const std = @import("std");
const builtin = @import("builtin");

/// Cross-platform way to retrieve terminal dimmensions across windows, linux and macos
/// by invoking the respective syscalls.
pub fn getTerminalSize(fd: std.fs.File.Handle) struct { rows: u16, cols: u16 } {
    switch (builtin.os.tag) {
        .windows => {
            var info: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            _ = std.os.windows.kernel32.GetConsoleScreenBufferInfo(fd, &info);
            return .{
                // info.dwSize.Y doesn't work on Windows Console Host, below works on all.
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

/// Terminal ansi escape sequences
pub const ESC = struct {
    pub const ERASE_ENTIRE = "\x1b[2J";
    pub const CURSOR_HOME = "\x1b[H";
    pub const CURSOR_HIDE = "\x1b[?25l";
};
