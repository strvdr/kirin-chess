const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var Bitboard: u64 = 0;
    try utils.printBitboard(Bitboard);
    Bitboard |= @as(u64, 1) << @intFromEnum(bitboard.boardSquares.e2);
    try utils.printBitboard(Bitboard);
    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
