const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const magic = @import("magics.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    attacks.initLeaperAttacks();
    //std.debug.print("Rand Num: {d}\n", .{});

    utils.printBitboard(@as(u64, magic.getRandomNumberU32()));
    utils.printBitboard(@as(u64, magic.getRandomNumberU32()) & 0xFFFF);
    utils.printBitboard(magic.getRandomNumberU64());
    utils.printBitboard(magic.generateMagicNumber());

    // const bitsInMask = utils.countBits(attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));
    // std.debug.print("Bits in mask: {d}\n", .{bitsInMask});
    // const occupancy = utils.setOccupancy(4095, bitsInMask, attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));

    try bw.flush(); // Don't forget to flush!
}
