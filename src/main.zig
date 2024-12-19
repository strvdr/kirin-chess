const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try utils.printBitboard(try attacks.maskPawnAttacks(@intFromEnum(bitboard.boardSquares.h4), @intFromEnum(bitboard.side.white)));
    try utils.printBitboard(try attacks.maskPawnAttacks(@intFromEnum(bitboard.boardSquares.f4), @intFromEnum(bitboard.side.white)));
    try utils.printBitboard(try attacks.maskPawnAttacks(@intFromEnum(bitboard.boardSquares.c5), @intFromEnum(bitboard.side.black)));

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
