const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");

fn getRandomNumber() u32 {
    var number: u32 = bitboard.state;

    number ^= number << 13;
    number ^= number >> 17;
    number ^= number << 5;

    bitboard.state = number;

    return number;
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    attacks.initLeaperAttacks();
    var randomNumber = getRandomNumber();
    std.debug.print("Rand Num: {d}\n", .{randomNumber});
    randomNumber = getRandomNumber();
    std.debug.print("Rand Num: {d}\n", .{randomNumber});
    randomNumber = getRandomNumber();
    std.debug.print("Rand Num: {d}\n", .{randomNumber});

    // const bitsInMask = utils.countBits(attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));
    // std.debug.print("Bits in mask: {d}\n", .{bitsInMask});
    // const occupancy = utils.setOccupancy(4095, bitsInMask, attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));

    // utils.printBitboard(occupancy);

    try bw.flush(); // Don't forget to flush!
}
