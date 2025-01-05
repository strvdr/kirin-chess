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
const utils = @import("utils.zig");
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
    std.debug.print("Side: {s}\n", .{side});
    if (bb.enpassant != @intFromEnum(bb.boardSquares.noSquare)) {
        std.debug.print("Enpassant: {s}\n", .{bb.squareCoordinates[bb.enpassant]});
    } else {
        std.debug.print("Enpassant: no\n", .{});
    }

    std.debug.print("Castling: ", .{});
    if ((bb.castle & @intFromEnum(bb.castlingRights.wk)) != 0) {
        std.debug.print("K", .{});
    } else {
        std.debug.print("-", .{});
    }

    if ((bb.castle & @intFromEnum(bb.castlingRights.wq)) != 0) {
        std.debug.print("Q", .{});
    } else {
        std.debug.print("-", .{});
    }
    if ((bb.castle & @intFromEnum(bb.castlingRights.bk)) != 0) {
        std.debug.print("k", .{});
    } else {
        std.debug.print("-", .{});
    }
    if ((bb.castle & @intFromEnum(bb.castlingRights.wq)) != 0) {
        std.debug.print("q", .{});
    } else {
        std.debug.print("-", .{});
    }
}

pub fn parseFEN(fen: []const u8) void {
    // Reset board state
    @memset(bb.bitboards[0..], 0);
    @memset(bb.occupancies[0..], 0);
    bb.sideToMove = 0;
    bb.enpassant = @intFromEnum(bb.boardSquares.noSquare);
    bb.castle = 0;

    var fenIndex: usize = 0;
    var fileIndex: usize = 0;

    // Parse piece positions
    for (0..8) |rank| {
        fileIndex = 0;
        while (fileIndex < 8) {
            const square: u6 = @intCast(rank * 8 + fileIndex);

            // Handle pieces
            if ((fen[fenIndex] >= 'a' and fen[fenIndex] <= 'z') or
                (fen[fenIndex] >= 'A' and fen[fenIndex] <= 'Z'))
            {
                const piece: u8 = bb.charPieces[fen[fenIndex]];
                utils.setBit(&bb.bitboards[piece], square);
                fenIndex += 1;
                fileIndex += 1;
            }

            // Handle empty squares
            else if (fen[fenIndex] >= '0' and fen[fenIndex] <= '9') {
                const offset = fen[fenIndex] - '0';
                fileIndex += offset; // -1 because the loop will increment file
                fenIndex += 1;
            }

            // Handle rank separator
            else if (fen[fenIndex] == '/') {
                fenIndex += 1;
            }
        }
    }

    // Skip to side to move
    fenIndex += 1;

    // Parse side to move
    bb.sideToMove = if (fen[fenIndex] == 'w') @intFromEnum(bb.side.white) else @intFromEnum(bb.side.black);

    // Skip to castling rights
    fenIndex += 2;

    // Parse castling rights
    while (fen[fenIndex] != ' ') : (fenIndex += 1) {
        switch (fen[fenIndex]) {
            'K' => bb.castle |= @intFromEnum(bb.castlingRights.wk),
            'Q' => bb.castle |= @intFromEnum(bb.castlingRights.wq),
            'k' => bb.castle |= @intFromEnum(bb.castlingRights.bk),
            'q' => bb.castle |= @intFromEnum(bb.castlingRights.bq),
            '-' => {},
            else => {},
        }
    }

    // Skip to en passant square
    fenIndex += 1;

    // Parse en passant square
    if (fen[fenIndex] != '-') {
        const file_val: i32 = fen[fenIndex] - 'a';
        const rank_val: i32 = 8 - (@as(i32, fen[fenIndex + 1] -% '0'));

        if (file_val >= 0 and file_val < 8 and
            rank_val >= 0 and rank_val < 8)
        {
            const file: i8 = @intCast(file_val);
            const rank: i8 = @intCast(rank_val);
            bb.enpassant = @intCast(rank * 8 + file);
        }
    }

    for (@intFromEnum(bb.pieceEncoding.P)..@intFromEnum(bb.pieceEncoding.K) + 1) |piece| {
        bb.occupancies[@intFromEnum(bb.side.white)] |= bb.bitboards[piece];
    }

    for (@intFromEnum(bb.pieceEncoding.p)..@intFromEnum(bb.pieceEncoding.k) + 1) |piece| {
        bb.occupancies[@intFromEnum(bb.side.black)] |= bb.bitboards[piece];
    }

    bb.occupancies[@intFromEnum(bb.side.both)] = bb.occupancies[@intFromEnum(bb.side.white)] | bb.occupancies[@intFromEnum(bb.side.black)];
}
