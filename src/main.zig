// This file is part of the Kirin Chess project.
//
// Kirin Chess is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kirin Chess is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kirin Chess.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const magic = @import("magics.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    attacks.initAll();

    //set white pawns
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.a2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.b2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.c2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.d2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.e2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.f2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.g2));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.P)], @intFromEnum(bitboard.boardSquares.h2));

    //set white knights
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.N)], @intFromEnum(bitboard.boardSquares.b1));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.N)], @intFromEnum(bitboard.boardSquares.g1));

    //set white bishop
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.B)], @intFromEnum(bitboard.boardSquares.c1));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.B)], @intFromEnum(bitboard.boardSquares.f1));

    //set white rook
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.R)], @intFromEnum(bitboard.boardSquares.h1));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.R)], @intFromEnum(bitboard.boardSquares.a1));

    //set white queen and king
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.Q)], @intFromEnum(bitboard.boardSquares.d1));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.K)], @intFromEnum(bitboard.boardSquares.e1));

    //set black pawns
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.a7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.b7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.c7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.d7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.e7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.f7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.g7));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.p)], @intFromEnum(bitboard.boardSquares.h7));

    //set white knights
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.n)], @intFromEnum(bitboard.boardSquares.b8));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.n)], @intFromEnum(bitboard.boardSquares.g8));

    //set white bishop
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.b)], @intFromEnum(bitboard.boardSquares.c8));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.b)], @intFromEnum(bitboard.boardSquares.f8));

    //set white rook
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.r)], @intFromEnum(bitboard.boardSquares.h8));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.r)], @intFromEnum(bitboard.boardSquares.a8));

    //set white queen and king
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.q)], @intFromEnum(bitboard.boardSquares.d8));
    utils.setBit(&bitboard.bitboards[@intFromEnum(bitboard.pieceEncoding.k)], @intFromEnum(bitboard.boardSquares.e8));

    bitboard.sideToMove = @intFromEnum(bitboard.side.white);
    utils.printBoard();
    try bw.flush(); // Don't forget to flush!
}
