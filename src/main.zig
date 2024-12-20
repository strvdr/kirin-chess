const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    try attacks.initLeaperAttacks();
    const bitsInMask = try utils.countBits(try attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));
    std.debug.print("Bits in mask: {d}\n", .{bitsInMask});
    const occupancy = try utils.setOccupancy(4095, bitsInMask, try attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));

    try utils.printBitboard(occupancy);

    try bw.flush(); // Don't forget to flush!
}
