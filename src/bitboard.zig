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

pub const emptyBoard = "8/8/8/8/8/8/8/8 w - - ";
pub const startPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ";
pub const kiwiPete = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1 ";
pub const killerMovePos = "rnbqkb1r/pp1p1pPp/8/2p1pP2/1P1P4/3P3P/P1P1P3/RNBQKBNR w KQkq e6 0 1 ";

pub const boardSquares = enum(u7) { a8, b8, c8, d8, e8, f8, g8, h8, a7, b7, c7, d7, e7, f7, g7, h7, a6, b6, c6, d6, e6, f6, g6, h6, a5, b5, c5, d5, e5, f5, g5, h5, a4, b4, c4, d4, e4, f4, g4, h4, a3, b3, c3, d3, e3, f3, g3, h3, a2, b2, c2, d2, e2, f2, g2, h2, a1, b1, c1, d1, e1, f1, g1, h1, noSquare };

pub const squareCoordinates: [64][]const u8 = .{ "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8", "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7", "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6", "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5", "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4", "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3", "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2", "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1" };

// bishop relevant occupancy bit count for every square on board
pub const bishopRelevantBits: [64]u5 = .{ 6, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 6 };

pub const rookRelevantBits: [64]u5 = .{ 12, 11, 11, 11, 11, 11, 11, 12, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 12, 11, 11, 11, 11, 11, 11, 12 };

// castling rights binary encoding
//    bin  dec
//   0001    1  white king can castle to the king side
//   0010    2  white king can castle to the queen side
//   0100    4  black king can castle to the king side
//   1000    8  black king can castle to the queen side
//
//    examples
//   1111       both sides an castle both directions
//   1001       black king => queen side, white king => king side

pub const castlingRights = enum(u4) { wk = 1, wq = 2, bk = 4, bq = 8 };

pub const pieceEncoding = enum(u4) { P, N, B, R, Q, K, p, n, b, r, q, k };

pub const charPieces = init: {
    var pieces: [128]u8 = undefined;
    @memset(&pieces, 0);

    pieces['P'] = @intFromEnum(pieceEncoding.P);
    pieces['N'] = @intFromEnum(pieceEncoding.N);
    pieces['B'] = @intFromEnum(pieceEncoding.B);
    pieces['R'] = @intFromEnum(pieceEncoding.R);
    pieces['Q'] = @intFromEnum(pieceEncoding.Q);
    pieces['K'] = @intFromEnum(pieceEncoding.K);
    pieces['p'] = @intFromEnum(pieceEncoding.p);
    pieces['n'] = @intFromEnum(pieceEncoding.n);
    pieces['b'] = @intFromEnum(pieceEncoding.b);
    pieces['r'] = @intFromEnum(pieceEncoding.r);
    pieces['q'] = @intFromEnum(pieceEncoding.q);
    pieces['k'] = @intFromEnum(pieceEncoding.k);

    break :init pieces;
};

pub const asciiPieces: []const u8 = "PNBRQKpnbrqk";
pub const unicodePieces: [12][]const u8 = .{ "♙", "♘", "♗", "♖", "♕", "♔", "♟︎", "♞", "♝", "♜", "♛", "♚" };
pub const bishopMagicNumbers: [64]u64 = .{
    0x40040822862081,
    0x40810a4108000,
    0x2008008400920040,
    0x61050104000008,
    0x8282021010016100,
    0x41008210400a0001,
    0x3004202104050c0,
    0x22010108410402,
    0x60400862888605,
    0x6311401040228,
    0x80801082000,
    0x802a082080240100,
    0x1860061210016800,
    0x401016010a810,
    0x1000060545201005,
    0x21000c2098280819,
    0x2020004242020200,
    0x4102100490040101,
    0x114012208001500,
    0x108000682004460,
    0x7809000490401000,
    0x420b001601052912,
    0x408c8206100300,
    0x2231001041180110,
    0x8010102008a02100,
    0x204201004080084,
    0x410500058008811,
    0x480a040008010820,
    0x2194082044002002,
    0x2008a20001004200,
    0x40908041041004,
    0x881002200540404,
    0x4001082002082101,
    0x8110408880880,
    0x8000404040080200,
    0x200020082180080,
    0x1184440400114100,
    0xc220008020110412,
    0x4088084040090100,
    0x8822104100121080,
    0x100111884008200a,
    0x2844040288820200,
    0x90901088003010,
    0x1000a218000400,
    0x1102010420204,
    0x8414a3483000200,
    0x6410849901420400,
    0x201080200901040,
    0x204880808050002,
    0x1001008201210000,
    0x16a6300a890040a,
    0x8049000441108600,
    0x2212002060410044,
    0x100086308020020,
    0x484241408020421,
    0x105084028429c085,
    0x4282480801080c,
    0x81c098488088240,
    0x1400000090480820,
    0x4444000030208810,
    0x1020142010820200,
    0x2234802004018200,
    0xc2040450820a00,
    0x2101021090020,
};

pub const rookMagicNumbers: [64]u64 = .{
    0x20a4001000600480,
    0x1120015428301060,
    0x4484000528840000,
    0xc1804001a0020050,
    0x2801120200000021,
    0x1009008054140098,
    0xce04800392012000,
    0x10011009a02,
    0x82212320a280408,
    0x206002908a0608,
    0x140010901050000,
    0x840484c0020204,
    0x2002114000082,
    0x8100421202100,
    0x80002a5a00408,
    0xa000002405044008,
    0x20300384228100,
    0x88201200080024,
    0x2690118101220002,
    0x680a2304006810,
    0x1040012002180,
    0x448c040801a08351,
    0x20a08181042010,
    0x4000064280808800,
    0x18401c0002004809,
    0x10008900080e4210,
    0x4020080091004002,
    0x402040008010260,
    0x40441000102024,
    0x490080900010,
    0x5100282024800502,
    0x10108108a000480,
    0x4221001040003100,
    0x400010c810260008,
    0x232000402208100,
    0x8010800040420,
    0x44040401001100,
    0x6820801014208800,
    0x584040080824054,
    0x2000040328008400,
    0x2214012000110900,
    0x1090058400a16010,
    0x4200100808040100,
    0xa0038404200190,
    0x20020241000110,
    0x20201000820812,
    0x4b0242700090,
    0x840140420c010,
    0x2002001a11140000,
    0xa806002220102020,
    0x24401c5480080010,
    0x21100401010109b2,
    0x20500120948040,
    0x12100010802344,
    0x24300030c1181802,
    0x202400e038208400,
    0x8100800880048022,
    0x1200404804900,
    0x480040404c12004,
    0x8848002805008,
    0x5882002180310a,
    0x8284821050c0,
    0x5040210044088021,
    0x121001000808,
};

pub var state: u32 = 1804289383;

pub const side = enum(u2) { white, black, both };

//                            WHITE PIECES
//
//
//        Pawns                  Knights              Bishops
//
//  8  0 0 0 0 0 0 0 0    8  0 0 0 0 0 0 0 0    8  0 0 0 0 0 0 0 0
//  7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0
//  6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0
//  5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0
//  4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0
//  3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0
//  2  1 1 1 1 1 1 1 1    2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0
//  1  0 0 0 0 0 0 0 0    1  0 1 0 0 0 0 1 0    1  0 0 1 0 0 1 0 0
//
//     a b c d e f g h       a b c d e f g h       a b c d e f g h
//
//
//         Rooks                 Queens                 King
//
//  8  0 0 0 0 0 0 0 0    8  0 0 0 0 0 0 0 0    8  0 0 0 0 0 0 0 0
//  7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0
//  6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0
//  5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0
//  4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0
//  3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0
//  2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0
//  1  1 0 0 0 0 0 0 1    1  0 0 0 1 0 0 0 0    1  0 0 0 0 1 0 0 0
//
//     a b c d e f g h       a b c d e f g h       a b c d e f g h
//
//
//                            BLACK PIECES
//
//
//        Pawns                  Knights              Bishops
//
//  8  0 0 0 0 0 0 0 0    8  0 1 0 0 0 0 1 0    8  0 0 1 0 0 1 0 0
//  7  1 1 1 1 1 1 1 1    7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0
//  6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0
//  5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0
//  4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0
//  3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0
//  2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0
//  1  0 0 0 0 0 0 0 0    1  0 0 0 0 0 0 0 0    1  0 0 0 0 0 0 0 0
//
//     a b c d e f g h       a b c d e f g h       a b c d e f g h
//
//
//         Rooks                 Queens                 King
//
//  8  1 0 0 0 0 0 0 1    8  0 0 0 1 0 0 0 0    8  0 0 0 0 1 0 0 0
//  7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0    7  0 0 0 0 0 0 0 0
//  6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0
//  5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0
//  4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0
//  3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0
//  2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0    2  0 0 0 0 0 0 0 0
//  1  0 0 0 0 0 0 0 0    1  0 0 0 0 0 0 0 0    1  0 0 0 0 0 0 0 0
//
//     a b c d e f g h       a b c d e f g h       a b c d e f g h
//
//
//
//                             OCCUPANCIES
//
//
//     White occupancy       Black occupancy       All occupancies
//
//  8  0 0 0 0 0 0 0 0    8  1 1 1 1 1 1 1 1    8  1 1 1 1 1 1 1 1
//  7  0 0 0 0 0 0 0 0    7  1 1 1 1 1 1 1 1    7  1 1 1 1 1 1 1 1
//  6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0    6  0 0 0 0 0 0 0 0
//  5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0    5  0 0 0 0 0 0 0 0
//  4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0    4  0 0 0 0 0 0 0 0
//  3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0    3  0 0 0 0 0 0 0 0
//  2  1 1 1 1 1 1 1 1    2  0 0 0 0 0 0 0 0    2  1 1 1 1 1 1 1 1
//  1  1 1 1 1 1 1 1 1    1  0 0 0 0 0 0 0 0    1  1 1 1 1 1 1 1 1
//
//
//
//                            ALL TOGETHER
//
//                        8  ♜ ♞ ♝ ♛ ♚ ♝ ♞ ♜
//                        7  ♟︎ ♟︎ ♟︎ ♟︎ ♟︎ ♟︎ ♟︎ ♟︎
//                        6  . . . . . . . .
//                        5  . . . . . . . .
//                        4  . . . . . . . .
//                        3  . . . . . . . .
//                        2  ♙ ♙ ♙ ♙ ♙ ♙ ♙ ♙
//                        1  ♖ ♘ ♗ ♕ ♔ ♗ ♘ ♖
//
//                           a b c d e f g h

pub var bitboards: [12]u64 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
pub var occupancies: [3]u64 = undefined;
pub var sideToMove: i2 = -1;
pub var enpassant: u7 = @intFromEnum(boardSquares.noSquare);
pub var castle: u4 = undefined;

pub fn initNewGame() void {
    //set white pawns
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.a2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.b2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.c2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.d2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.e2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.f2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.g2));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.P)], @intFromEnum(boardSquares.h2));

    //set white kn
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.N)], @intFromEnum(boardSquares.b1));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.N)], @intFromEnum(boardSquares.g1));

    //set white bi
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.B)], @intFromEnum(boardSquares.c1));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.B)], @intFromEnum(boardSquares.f1));

    //set white ro
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.R)], @intFromEnum(boardSquares.h1));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.R)], @intFromEnum(boardSquares.a1));

    //set white quing
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.Q)], @intFromEnum(boardSquares.d1));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.K)], @intFromEnum(boardSquares.e1));

    //set black pa
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.a7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.b7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.c7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.d7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.e7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.f7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.g7));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.p)], @intFromEnum(boardSquares.h7));

    //set white knights
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.n)], @intFromEnum(boardSquares.b8));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.n)], @intFromEnum(boardSquares.g8));

    //set white bi
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.b)], @intFromEnum(boardSquares.c8));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.b)], @intFromEnum(boardSquares.f8));

    //set white ro
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.r)], @intFromEnum(boardSquares.h8));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.r)], @intFromEnum(boardSquares.a8));

    //set white quing
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.q)], @intFromEnum(boardSquares.d8));
    utils.setBit(&bitboards[@intFromEnum(pieceEncoding.k)], @intFromEnum(boardSquares.e8));

    sideToMove = @intFromEnum(side.white);
    enpassant = @intFromEnum(boardSquares.noSquare);
    castle |= @intFromEnum(castlingRights.wk);
    castle |= @intFromEnum(castlingRights.wq);
    castle |= @intFromEnum(castlingRights.bk);
    castle |= @intFromEnum(castlingRights.bq);
}
