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

    pub const bishopMagicNumbers = [64]u64{
        0x0408180108640100, // 0
        0x0008020082020410, // 1
        0x0208009418800000, // 2
        0x00a42400820a8248, // 3
        0x08420210212c0084, // 4
        0xc028900420041220, // 5
        0x0006084c02080054, // 6
        0x6012240504882000, // 7
        0x0209401004114048, // 8
        0x0000481001005101, // 9
        0xc000040146060000, // 10
        0x00002820a0a00a00, // 11
        0x2020411041002000, // 12
        0x28000a0803081400, // 13
        0xa2000202022005c2, // 14
        0x0050010c02020310, // 15
        0x80200d10041000b2, // 16
        0x0808191010013440, // 17
        0x2090003800801611, // 18
        0x4008045088250000, // 19
        0x8c90100202102040, // 20
        0x0086000104420215, // 21
        0x0020800202012000, // 22
        0x02c1804124041220, // 23
        0x0110400808080110, // 24
        0x0801080021080100, // 25
        0x0004880010004211, // 26
        0x07010800040a0020, // 27
        0x0210802082020040, // 28
        0x8064004028080220, // 29
        0x001114000100a801, // 30
        0x040880880a021080, // 31
        0x0e42088654202000, // 32
        0x02c8041081420200, // 33
        0x0052080201040422, // 34
        0x0058202020080080, // 35
        0x0860008401008020, // 36
        0x084a140640480802, // 37
        0x0004040040008800, // 38
        0x0024088880120060, // 39
        0x8401196050402080, // 40
        0x0004020202401000, // 41
        0xa400802801034810, // 42
        0x0000024208008880, // 43
        0x0200840894008200, // 44
        0xc621026802001040, // 45
        0x040418e244008320, // 46
        0x2001040114400208, // 47
        0x0002022220c401a2, // 48
        0x8201104802480001, // 49
        0x0001084210900340, // 50
        0x0000000020a80142, // 51
        0x0400001020220000, // 52
        0x000a089001220808, // 53
        0x4840040400820800, // 54
        0x2004280094208800, // 55
        0x0001402c10080480, // 56
        0x0011021086280201, // 57
        0x0001200042080400, // 58
        0x20c0284024840400, // 59
        0x0260280204050400, // 60
        0x0018040810900088, // 61
        0x0000202004809080, // 62
        0x8062080224004201, // 63
    };

    // Generated Rook Magic Numbers
    pub const rookMagicNumbers = [64]u64{
        0x1080002080400010, // 0
        0xc040001000402004, // 1
        0x0680100080200008, // 2
        0x2880080080061000, // 3
        0x0480040080080002, // 4
        0x0580020080012400, // 5
        0x0080020000800100, // 6
        0x0080008000d82500, // 7
        0x2012800220804002, // 8
        0x0000402000401000, // 9
        0x0002802000801002, // 10
        0x6182004200082010, // 11
        0x0600800800800401, // 12
        0x1006000830040200, // 13
        0x000300140100c200, // 14
        0x040a000081004204, // 15
        0x4004228000400080, // 16
        0x80c0808040002000, // 17
        0x0010110020010440, // 18
        0x0008008010000880, // 19
        0x0121010010040801, // 20
        0x0000808002000400, // 21
        0x4005808002000100, // 22
        0x0001820000408104, // 23
        0x0b00802080004000, // 24
        0x0000500240002000, // 25
        0x0003084100122000, // 26
        0x0000100100210008, // 27
        0x0800080080040080, // 28
        0x0232000200050890, // 29
        0x2000010400222830, // 30
        0x00021102000840a4, // 31
        0x2008400024800080, // 32
        0x0000400088802003, // 33
        0x0232018692002040, // 34
        0x0010100081802800, // 35
        0x230a000822001005, // 36
        0x0044010040400200, // 37
        0x0082020104001008, // 38
        0x8002065182000401, // 39
        0x2980004020004000, // 40
        0x8410002000404000, // 41
        0x0002001040820022, // 42
        0x0048000810008080, // 43
        0x0003000800110005, // 44
        0x80520104d0020008, // 45
        0x0004100e08540001, // 46
        0x0000104091120004, // 47
        0x0410402080010100, // 48
        0x8400802100400100, // 49
        0x0000801000200080, // 50
        0x4000080010008480, // 51
        0x2800800400080080, // 52
        0x8020200410400801, // 53
        0x0845015008021400, // 54
        0x0410005084010a00, // 55
        0x0880030094806141, // 56
        0x0000802011004001, // 57
        0x0004884220010111, // 58
        0x682200290c405022, // 59
        0x0001002230080005, // 60
        0x802100024c000813, // 61
        0x00001002012800a4, // 62
        0x0000802401008042, // 63
    };
};

pub const Display = struct {
    pub const asciiPieces: []const u8 = "PNBRQKpnbrqk";
    pub const unicodePieces: [12][]const u8 = .{ "♙", "♘", "♗", "♖", "♕", "♔", "♟︎", "♞", "♝", "♜", "♛", "♚" };
};

pub var state: u64 = 1804289383;
