const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    //try utils.printBitboard(try attacks.maskBishopAttacks(@intFromEnum(bitboard.boardSquares.d4)));

    try attacks.initLeaperAttacks();

    var block = @as(u64, 0);
    block = try utils.setBit(&block, @intFromEnum(bitboard.boardSquares.b6));
    block = try utils.setBit(&block, @intFromEnum(bitboard.boardSquares.g7));
    block = try utils.setBit(&block, @intFromEnum(bitboard.boardSquares.e3));
    block = try utils.setBit(&block, @intFromEnum(bitboard.boardSquares.b2));
    try utils.printBitboard(block);

    // for (0..64) |square| {
    //     //std.debug.print("\nPawn: \n", .{});
    //     //try utils.printBitboard(attacks.pawnAttacks[@intFromEnum(bitboard.side.black)][square]);
    //     //std.debug.print("\nKnight: \n", .{});
    //     //try utils.printBitboard(attacks.knightAttacks[square]);
    //     //std.debug.print("\nKing: \n", .{});
    //     //try utils.printBitboard(attacks.kingAttacks[square]);
    //     std.debug.print("\nRook: \n", .{});
    //     const index: u6 = @intCast(square);
    //     try utils.printBitboard(try attacks.bishopAttacksOTF(index));
    // }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}
