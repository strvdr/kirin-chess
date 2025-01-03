// This file is part of the Kirin Chess project.
//
// Kirin Chess is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kirin Chess is distributed in the  hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kirin Chess.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const bb = @import("bitboard.zig");
const assert = std.debug.assert;

//Bit Manipulations
pub fn getBit(bitboard: u64, square: u6) u1 {
    if (bitboard & (@as(u64, 1) << square) == 0) return 0 else return 1;
}

pub fn setBit(bitboard: *u64, square: u6) void {
    bitboard.* |= (@as(u64, 1) << square);
}

pub fn popBit(bitboard: *u64, square: u6) void {
    if (getBit(bitboard.*, square) != 0) {
        bitboard.* ^= (@as(u64, 1) << square);
    }
}

pub fn countBits(bitboard: u64) u6 {
    var bitboardCopy = bitboard;
    var bits_set: usize = 0;
    while (bitboardCopy != 0) : (bits_set += 1) {
        bitboardCopy &= bitboardCopy - 1;
    }
    return @as(u6, @truncate(bits_set));
}

pub fn getLSBindex(bitboard: u64) i8 {
    const bitboardCopy = bitboard;
    if (bitboardCopy != 0) {
        return countBits((bitboardCopy & (~bitboardCopy + 1)) - 1);
    } else {
        return -1;
    }
}

pub fn setOccupancy(index: u32, bitsInMask: u6, attackMask: u64) u64 {
    var occupancy: u64 = @as(u64, 0);
    var attackMaskCopy = attackMask;
    for (0..bitsInMask) |count| {
        const lsbIndex = getLSBindex(attackMaskCopy);
        if (lsbIndex == -1) {
            continue;
        }
        const square: u6 = @intCast(lsbIndex);
        popBit(&attackMaskCopy, square);
        const bitShift: u6 = @intCast(count);
        if ((index & (@as(u64, 1) << bitShift)) != 0) {
            occupancy |= @as(u64, 1) << square;
        }
    }

    return occupancy;
}

//Print Board Functions
pub fn printBitboard(bitboard: u64) void {
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

pub fn printBoard() void {
    std.debug.print("\n", .{});
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            if (file == 0) std.debug.print("  {d} ", .{8 - rank});
            var piece: i5 = -1;
            for (0..12) |bitboardPiece| {
                if (getBit(bb.bitboards[bitboardPiece], square) != 0) {
                    piece = @intCast(bitboardPiece);
                    break;
                } else {
                    piece = -1;
                }
                //std.debug.print("Piece: {d}\n", .{piece});
            }
            if (piece == -1) {
                std.debug.print(" .", .{});
            } else {
                std.debug.print(" {s}", .{bb.unicodePieces[@intCast(piece)]});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n     a b c d e f g h\n\n", .{});
    const side = if (bb.sideToMove == 0) "white" else "black";
    std.debug.print("Side: {s}", .{side});
}
