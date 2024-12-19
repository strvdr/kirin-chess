const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");

//       not A file             not H file             not AB file            not HG file
//
//  8  0 1 1 1 1 1 1 1     8  1 1 1 1 1 1 1 0     8  0 0 1 1 1 1 1 1     8  1 1 1 1 1 1 0 0
//  7  0 1 1 1 1 1 1 1     7  1 1 1 1 1 1 1 0     7  0 0 1 1 1 1 1 1     7  1 1 1 1 1 1 0 0
//  6  0 1 1 1 1 1 1 1     6  1 1 1 1 1 1 1 0     6  0 0 1 1 1 1 1 1     6  1 1 1 1 1 1 0 0
//  5  0 1 1 1 1 1 1 1     5  1 1 1 1 1 1 1 0     5  0 0 1 1 1 1 1 1     5  1 1 1 1 1 1 0 0
//  4  0 1 1 1 1 1 1 1     4  1 1 1 1 1 1 1 0     4  0 0 1 1 1 1 1 1     4  1 1 1 1 1 1 0 0
//  3  0 1 1 1 1 1 1 1     3  1 1 1 1 1 1 1 0     3  0 0 1 1 1 1 1 1     3  1 1 1 1 1 1 0 0
//  2  0 1 1 1 1 1 1 1     2  1 1 1 1 1 1 1 0     2  0 0 1 1 1 1 1 1     2  1 1 1 1 1 1 0 0
//  1  0 1 1 1 1 1 1 1     1  1 1 1 1 1 1 1 0     1  0 0 1 1 1 1 1 1     1  1 1 1 1 1 1 0 0
//
//     a b c d e f g h        a b c d e f g h        a b c d e f g h        a b c d e f g h
//
const not_A_file: u64 = 18374403900871474942;
const not_H_file: u64 = 9187201950435737471;
const not_HG_file: u64 = 4557430888798830399;
const not_AB_file: u64 = 18229723555195321596;

pub var pawnAttacks: [2][64]u64 = undefined;

pub fn maskPawnAttacks(side: u1, square: u6) !u64 {
    var attacks: u64 = @as(u64, 0);
    var Bitboard: u64 = @as(u64, 0);

    Bitboard = try utils.setBit(&Bitboard, square);

    if (side == 0) {
        if (((Bitboard >> 7) & not_A_file) != 0) {
            attacks |= (Bitboard >> 7);
        }
        if (((Bitboard >> 9) & not_H_file) != 0) {
            attacks |= (Bitboard >> 9);
        }
    } else {
        if (((Bitboard << 7) & not_H_file) != 0) {
            attacks |= (Bitboard << 7);
        }
        if (((Bitboard << 9) & not_A_file) != 0) {
            attacks |= (Bitboard << 9);
        }
    }
    return attacks;
}

pub fn initLeaperAttacks() !void {
    for (0..64) |index| {
        const square: u6 = @intCast(index);
        pawnAttacks[@intFromEnum(bitboard.side.white)][square] = try maskPawnAttacks(@intFromEnum(bitboard.side.white), @as(u6, square));
        pawnAttacks[@intFromEnum(bitboard.side.black)][square] = try maskPawnAttacks(@intFromEnum(bitboard.side.black), @as(u6, square));
    }
}
