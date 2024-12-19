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
pub var knightAttacks: [64]u64 = undefined;
pub var kingAttacks: [64]u64 = undefined;
pub var bishopAttacks: [64]u64 = undefined;

fn maskPawnAttacks(side: u1, square: u6) !u64 {
    var attacks: u64 = @as(u64, 0);
    var Bitboard: u64 = @as(u64, 0);

    Bitboard = try utils.setBit(&Bitboard, square);

    if (side == 0) {
        if (((Bitboard >> 7) & not_A_file) != 0) attacks |= (Bitboard >> 7);
        if (((Bitboard >> 9) & not_H_file) != 0) attacks |= (Bitboard >> 9);
    } else {
        if (((Bitboard << 7) & not_H_file) != 0) attacks |= (Bitboard << 7);
        if (((Bitboard << 9) & not_A_file) != 0) attacks |= (Bitboard << 9);
    }

    return attacks;
}

fn maskKnightAttacks(square: u6) !u64 {
    var attacks: u64 = @as(u64, 0);
    var Bitboard: u64 = @as(u64, 0);

    Bitboard = try utils.setBit(&Bitboard, square);

    if (((Bitboard >> 17) & not_H_file) != 0) attacks |= (Bitboard >> 17);
    if (((Bitboard >> 15) & not_A_file) != 0) attacks |= (Bitboard >> 15);
    if (((Bitboard >> 10) & not_HG_file) != 0) attacks |= (Bitboard >> 10);
    if (((Bitboard >> 6) & not_AB_file) != 0) attacks |= (Bitboard >> 6);
    if (((Bitboard << 17) & not_A_file) != 0) attacks |= (Bitboard << 17);
    if (((Bitboard << 15) & not_H_file) != 0) attacks |= (Bitboard << 15);
    if (((Bitboard << 10) & not_AB_file) != 0) attacks |= (Bitboard << 10);
    if (((Bitboard << 6) & not_HG_file) != 0) attacks |= (Bitboard << 6);

    return attacks;
}

fn maskKingAttacks(square: u6) !u64 {
    var attacks: u64 = @as(u64, 0);
    var Bitboard: u64 = @as(u64, 0);

    Bitboard = try utils.setBit(&Bitboard, square);
    if ((Bitboard >> 8) != 0) attacks |= (Bitboard >> 8);
    if (((Bitboard >> 9) & not_H_file) != 0) attacks |= (Bitboard >> 9);
    if (((Bitboard >> 7) & not_A_file) != 0) attacks |= (Bitboard >> 7);
    if (((Bitboard >> 1) & not_H_file) != 0) attacks |= (Bitboard >> 1);
    if ((Bitboard << 8) != 0) attacks |= (Bitboard << 8);
    if (((Bitboard << 9) & not_A_file) != 0) attacks |= (Bitboard << 9);
    if (((Bitboard << 7) & not_H_file) != 0) attacks |= (Bitboard << 7);
    if (((Bitboard << 1) & not_A_file) != 0) attacks |= (Bitboard << 1);

    return attacks;
}

pub fn maskBishopAttacks(square: u6) !u64 {
    var attacks: u64 = @as(u64, 0);

    const targetRank: i8 = square / 8;
    const targetFile: i8 = square % 8;

    var rank: i8 = targetRank + 1;
    var file: i8 = targetFile + 1;

    while (rank <= 6 and file <= 6) {
        const result: u6 = @intCast(rank * 8 + file);
        attacks |= @as(u64, 1) << result;
        rank += 1;
        file += 1;
    }

    rank = targetRank - 1;
    file = targetFile + 1;

    while (rank >= 1 and file <= 6) {
        const result: u6 = @intCast(rank * 8 + file);
        attacks |= @as(u64, 1) << result;
        rank -= 1;
        file += 1;
    }

    rank = targetRank + 1;
    file = targetFile - 1;

    while (rank <= 6 and file >= 1) {
        const result: u6 = @intCast(rank * 8 + file);
        attacks |= @as(u64, 1) << result;
        rank += 1;
        file -= 1;
    }

    rank = targetRank - 1;
    file = targetFile - 1;

    while (rank >= 1 and file >= 1) {
        const result: u6 = @intCast(rank * 8 + file);
        attacks |= @as(u64, 1) << result;
        rank -= 1;
        file -= 1;
    }

    return attacks;
}

pub fn initLeaperAttacks() !void {
    for (0..64) |index| {
        const square: u6 = @intCast(index);
        pawnAttacks[@intFromEnum(bitboard.side.white)][square] = try maskPawnAttacks(@intFromEnum(bitboard.side.white), @as(u6, square));
        pawnAttacks[@intFromEnum(bitboard.side.black)][square] = try maskPawnAttacks(@intFromEnum(bitboard.side.black), @as(u6, square));
        knightAttacks[square] = try maskKnightAttacks(square);
        kingAttacks[square] = try maskKingAttacks(square);
    }
}
