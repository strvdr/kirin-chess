const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try utils.printBitboard(try attacks.maskPawnAttacks(@intFromEnum(bitboard.side.black), @intFromEnum(bitboard.boardSquares.c5)));

    try attacks.initLeaperAttacks();

    for (0..64) |square| {
        try utils.printBitboard(attacks.pawnAttacks[@intFromEnum(bitboard.side.black)][square]);
    }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
