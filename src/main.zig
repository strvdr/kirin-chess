const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    //try utils.printBitboard(try attacks.maskKnightAttacks(@intFromEnum(bitboard.boardSquares.e4)));

    try attacks.initLeaperAttacks();

    for (0..64) |square| {
        std.debug.print("\nPawn: \n", .{});
        try utils.printBitboard(attacks.pawnAttacks[@intFromEnum(bitboard.side.black)][square]);
        std.debug.print("\nKnight: \n", .{});
        try utils.printBitboard(attacks.knightAttacks[square]);
    }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
