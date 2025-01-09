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

pub const Position = struct {
    pub const empty = "8/8/8/8/8/8/8/8 w - - ";
    pub const start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ";
    pub const kiwiPete = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1 ";
    pub const killer = "rnbqkb1r/pp1p1pPp/8/2p1pP2/1P1P4/3P3P/P1P1P3/RNBQKBNR w KQkq e6 0 1 ";
};

pub const Square = enum(u7) {
    a8,
    b8,
    c8,
    d8,
    e8,
    f8,
    g8,
    h8,
    a7,
    b7,
    c7,
    d7,
    e7,
    f7,
    g7,
    h7,
    a6,
    b6,
    c6,
    d6,
    e6,
    f6,
    g6,
    h6,
    a5,
    b5,
    c5,
    d5,
    e5,
    f5,
    g5,
    h5,
    a4,
    b4,
    c4,
    d4,
    e4,
    f4,
    g4,
    h4,
    a3,
    b3,
    c3,
    d3,
    e3,
    f3,
    g3,
    h3,
    a2,
    b2,
    c2,
    d2,
    e2,
    f2,
    g2,
    h2,
    a1,
    b1,
    c1,
    d1,
    e1,
    f1,
    g1,
    h1,
    noSquare,

    pub fn toCoordinates(self: Square) ![2]u8 {
        const square = @intFromEnum(self);
        if (square >= 64) return error.InvalidSquare;

        return .{
            @as(u8, 'a') + @as(u8, @intCast(square % 8)),
            @as(u8, '1') + @as(u8, @intCast(square / 8)),
        };
    }
};

pub const Piece = enum(u4) {
    P,
    N,
    B,
    R,
    Q,
    K,
    p,
    n,
    b,
    r,
    q,
    k,

    pub fn toPromotionChar(self: Piece) u8 {
        return switch (self) {
            .Q, .q => 'q',
            .R, .r => 'r',
            .B, .b => 'b',
            .N, .n => 'n',
            else => ' ',
        };
    }

    pub fn isWhite(self: Piece) bool {
        return @intFromEnum(self) <= @intFromEnum(Piece.K);
    }
};

pub const Side = enum(u2) {
    white,
    black,
    both,
    pub fn opposite(self: Side) Side {
        return switch (self) {
            .white => .black,
            .black => .white,
            .both => .both,
        };
    }
};

pub const CastlingRights = packed struct(u4) {
    whiteKingside: bool = false,
    whiteQueenside: bool = false,
    blackKingside: bool = false,
    blackQueenside: bool = false,

    pub fn all() CastlingRights {
        return .{
            .whiteKingside = true,
            .whiteQueenside = true,
            .blackKingside = true,
            .blackQueenside = true,
        };
    }
};

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

pub const Board = struct {
    bitboard: [12]u64 = .{0} ** 12,
    occupancy: [3]u64 = undefined,
    sideToMove: Side = .white,
    enpassant: Square = .noSquare,
    castling: CastlingRights = .{},

    pub fn init() Board {
        std.debug.print("init board called here", .{});
        return .{};
    }

    pub fn initStartPosition(self: *Board) void {
        std.debug.print("init start pos called here", .{});
        self.setPiece(.P, .{ .a2, .b2, .c2, .d2, .e2, .f2, .g2, .h2 });
        self.setPiece(.N, .{ .b1, .g1 });
        self.setPiece(.B, .{ .c1, .f1 });
        self.setPiece(.R, .{ .a1, .h1 });
        self.setPiece(.Q, .{.d1});
        self.setPiece(.K, .{.e1});

        // Black pieces
        self.setPiece(.p, .{ .a7, .b7, .c7, .d7, .e7, .f7, .g7, .h7 });
        self.setPiece(.n, .{ .b8, .g8 });
        self.setPiece(.b, .{ .c8, .f8 });
        self.setPiece(.r, .{ .a8, .h8 });
        self.setPiece(.q, .{.d8});
        self.setPiece(.k, .{.e8});

        self.sideToMove = .white;
        self.enpassant = .noSquare;
        self.castling = CastlingRights.all();
        self.updateOccupancy();
    }

    fn setPiece(self: *Board, piece: Piece, squares: Square) void {
        for (squares) |square| {
            utils.setBit(&self.bitboard[@intFromEnum(piece)], @intFromEnum(square));
        }
    }

    pub fn updateOccupancy(self: *Board) void {
        self.occupancy = .{ 0, 0, 0 };

        std.debug.print("Updating occupancy:\n", .{});
        for (0..12) |i| {
            const piece = @as(Piece, @enumFromInt(i));
            const piece_bb = self.bitboard[i];
            std.debug.print("  Piece {s} bitboard: {x}\n", .{ @tagName(piece), piece_bb });

            if (piece.isWhite()) {
                self.occupancy[@intFromEnum(Side.white)] |= piece_bb;
            } else {
                self.occupancy[@intFromEnum(Side.black)] |= piece_bb;
            }
        }

        self.occupancy[@intFromEnum(Side.both)] = self.occupancy[@intFromEnum(Side.white)] |
            self.occupancy[@intFromEnum(Side.black)];

        std.debug.print("Updated occupancy:\n  White: {x}\n  Black: {x}\n  Both: {x}\n", .{
            self.occupancy[@intFromEnum(Side.white)],
            self.occupancy[@intFromEnum(Side.black)],
            self.occupancy[@intFromEnum(Side.both)],
        });
    }
};

pub const charPieces = init: {
    var pieces: [128]u8 = undefined;
    @memset(&pieces, 0);

    pieces['P'] = @intFromEnum(Piece);
    pieces['N'] = @intFromEnum(Piece);
    pieces['B'] = @intFromEnum(Piece);
    pieces['R'] = @intFromEnum(Piece);
    pieces['Q'] = @intFromEnum(Piece);
    pieces['K'] = @intFromEnum(Piece);
    pieces['p'] = @intFromEnum(Piece);
    pieces['n'] = @intFromEnum(Piece);
    pieces['b'] = @intFromEnum(Piece);
    pieces['r'] = @intFromEnum(Piece);
    pieces['q'] = @intFromEnum(Piece);
    pieces['k'] = @intFromEnum(Piece);

    break :init pieces;
};

pub const Magic = struct {
    pub const bishopRelevantBits: [64]u5 = .{ 6, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 6 };

    pub const rookRelevantBits: [64]u5 = .{ 12, 11, 11, 11, 11, 11, 11, 12, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 12, 11, 11, 11, 11, 11, 11, 12 };

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
        0xa080041440042080,
        0xa840200410004001,
        0xc800c1000200081,
        0x100081001000420,
        0x200020010080420,
        0x3001c0002010008,
        0x8480008002000100,
        0x2080088004402900,
        0x800098204000,
        0x2024401000200040,
        0x100802000801000,
        0x120800800801000,
        0x208808088000400,
        0x2802200800400,
        0x2200800100020080,
        0x801000060821100,
        0x80044006422000,
        0x100808020004000,
        0x12108a0010204200,
        0x140848010000802,
        0x481828014002800,
        0x8094004002004100,
        0x4010040010010802,
        0x20008806104,
        0x100400080208000,
        0x2040002120081000,
        0x21200680100081,
        0x20100080080080,
        0x2000a00200410,
        0x20080800400,
        0x80088400100102,
        0x80004600042881,
        0x4040008040800020,
        0x440003000200801,
        0x4200011004500,
        0x188020010100100,
        0x14800401802800,
        0x2080040080800200,
        0x124080204001001,
        0x200046502000484,
        0x480400080088020,
        0x1000422010034000,
        0x30200100110040,
        0x100021010009,
        0x2002080100110004,
        0x202008004008002,
        0x20020004010100,
        0x2048440040820001,
        0x101002200408200,
        0x40802000401080,
        0x4008142004410100,
        0x2060820c0120200,
        0x1001004080100,
        0x20c020080040080,
        0x2935610830022400,
        0x44440041009200,
        0x280001040802101,
        0x2100190040002085,
        0x80c0084100102001,
        0x4024081001000421,
        0x20030a0244872,
        0x12001008414402,
        0x2006104900a0804,
        0x1004081002402,
    };
};

pub const Display = struct {
    pub const asciiPieces: []const u8 = "PNBRQKpnbrqk";
    pub const unicodePieces: [12][]const u8 = .{ "♙", "♘", "♗", "♖", "♕", "♔", "♟︎", "♞", "♝", "♜", "♛", "♚" };
};

pub var state: u64 = 1804289383;
