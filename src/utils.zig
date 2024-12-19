const std = @import("std");

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
