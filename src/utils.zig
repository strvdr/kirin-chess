const std = @import("std");
const assert = std.debug.assert;

//Bit Manipulations
pub fn getBit(bitboard: u64, square: u6) u1 {
    if (bitboard & (@as(u64, 1) << square) == 0) return 0 else return 1;
}

pub fn setBit(bitboard: *u64, square: u6) !u64 {
    bitboard.* |= (@as(u64, 1) << square);
    return bitboard.*;
}

pub fn popBit(bitboard: *u64, square: u6) !u64 {
    if (getBit(bitboard.*, square) != 0) {
        bitboard.* ^= (@as(u64, 1) << square);
    }
    return bitboard.*;
}

pub fn countBits(bitboard: u64) !u6 {
    var bitboardCopy = bitboard;
    var bits_set: usize = 0;
    while (bitboardCopy != 0) : (bits_set += 1) {
        bitboardCopy &= bitboardCopy - 1;
    }
    return @as(u6, @truncate(bits_set));
}

pub fn getLSBindex(bitboard: u64) !i8 {
    const bitboardCopy = bitboard;
    if (bitboardCopy != 0) {
        return try countBits((bitboardCopy & (~bitboardCopy + 1)) - 1);
    } else {
        return -1;
    }
}

pub fn setOccupancy(index: u32, bitsInMask: u6, attackMask: u64) !u64 {
    var occupancy: u64 = @as(u64, 0);
    var attackMaskCopy = attackMask;
    for (0..bitsInMask) |count| {
        const square: u6 = @intCast(try getLSBindex(attackMaskCopy));
        attackMaskCopy = try popBit(&attackMaskCopy, square);
        const w: u6 = @intCast(count);
        if ((index & (@as(u64, 1) << w)) != 0) {
            occupancy |= @as(u64, 1) << square;
        }
    }

    return occupancy;
}

//Print Board Functions
pub fn printBitboard(bitboard: u64) !void {
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            if (file == 0) std.debug.print("  {d}  ", .{8 - rank});
            const isOccupied: u1 = getBit(bitboard, square);
            std.debug.print(" {d} ", .{isOccupied});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n      a  b  c  d  e  f  g  h \n\n", .{});

    //print bitboard as unsigned decimal number
    std.debug.print("      Bitboard: {d}\n\n", .{bitboard});
}
