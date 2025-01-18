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
const board = @import("bitboard.zig");

// File masks as constants
pub const FileMask = struct {
    pub const notA: u64 = 18374403900871474942;
    pub const notH: u64 = 9187201950435737471;
    pub const notHG: u64 = 4557430888798830399;
    pub const notAB: u64 = 18229723555195321596;
};

// Pre-calculated attack tables
pub const AttackTable = struct {
    pawn: [2][64]u64 = undefined, // [side][square]
    knight: [64]u64 = undefined, // [square]
    king: [64]u64 = undefined, // [square]
    bishopMasks: [64]u64 = undefined,
    rookMasks: [64]u64 = undefined,
    bishop: [64][512]u64 = undefined, // [square][magicIndex]
    rook: [64][4096]u64 = undefined, // [square][magicIndex]

    pub fn init(self: *AttackTable) void {
        self.initLeaperAttacks();
        self.initSliderAttacks(true); // bishop
        self.initSliderAttacks(false); // rook
    }

    fn initLeaperAttacks(self: *AttackTable) void {
        for (0..64) |sq| {
            const square = @as(u6, @intCast(sq));
            self.pawn[0][square] = maskPawnAttacks(.white, square);
            self.pawn[1][square] = maskPawnAttacks(.black, square);
            self.knight[square] = maskKnightAttacks(square);
            self.king[square] = maskKingAttacks(square);
        }
    }

    fn initSliderAttacks(self: *AttackTable, is_bishop: bool) void {
        for (0..64) |sq| {
            const square = @as(u6, @intCast(sq));
            if (is_bishop) {
                self.bishopMasks[square] = maskBishopAttacks(square);
                const mask = self.bishopMasks[square];
                const bits = utils.countBits(mask);
                const occupancyIndices = @as(u64, 1) << bits;

                for (0..occupancyIndices) |idx| {
                    const index = @as(u12, @intCast(idx));
                    const occupancy = utils.setOccupancy(index, bits, mask);
                    const magicIndex =
                        (occupancy *% board.Magic.bishopMagicNumbers[square]) >>
                        @intCast(@as(u8, 64) - board.Magic.bishopRelevantBits[square]);
                    self.bishop[square][magicIndex] = bishopAttacksOTF(square, occupancy);
                }
            } else {
                self.rookMasks[square] = maskRookAttacks(square);
                const mask = self.rookMasks[square];
                const bits = utils.countBits(mask);
                const occupancyIndices = @as(u64, 1) << bits;

                for (0..occupancyIndices) |idx| {
                    const index = @as(u12, @intCast(idx));
                    const occupancy = utils.setOccupancy(index, bits, mask);
                    const magicIndex =
                        (occupancy *% board.Magic.rookMagicNumbers[square]) >>
                        @intCast(@as(u8, 64) - board.Magic.rookRelevantBits[square]);
                    self.rook[square][magicIndex] = rookAttacksOTF(square, occupancy);
                }
            }
        }
    }
};

fn maskPawnAttacks(side: board.Side, square: u6) u64 {
    var attacks: u64 = 0;
    var bb: u64 = 0;

    utils.setBit(&bb, square);

    switch (side) {
        .white => {
            if (((bb >> 7) & FileMask.notA) != 0) attacks |= (bb >> 7);
            if (((bb >> 9) & FileMask.notH) != 0) attacks |= (bb >> 9);
        },
        .black => {
            if (((bb << 7) & FileMask.notH) != 0) attacks |= (bb << 7);
            if (((bb << 9) & FileMask.notA) != 0) attacks |= (bb << 9);
        },
        .both => {},
    }

    return attacks;
}

fn maskKnightAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const bb: u64 = @as(u64, 1) << square;

    if ((bb >> 17) & FileMask.notH != 0) attacks |= (bb >> 17);
    if ((bb >> 15) & FileMask.notA != 0) attacks |= (bb >> 15);
    if ((bb >> 10) & FileMask.notHG != 0) attacks |= (bb >> 10);
    if ((bb >> 6) & FileMask.notAB != 0) attacks |= (bb >> 6);
    if ((bb << 17) & FileMask.notA != 0) attacks |= (bb << 17);
    if ((bb << 15) & FileMask.notH != 0) attacks |= (bb << 15);
    if ((bb << 10) & FileMask.notAB != 0) attacks |= (bb << 10);
    if ((bb << 6) & FileMask.notHG != 0) attacks |= (bb << 6);

    return attacks;
}

fn maskKingAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const bb: u64 = @as(u64, 1) << square;

    if (bb >> 8 != 0) attacks |= (bb >> 8);
    if ((bb >> 9) & FileMask.notH != 0) attacks |= (bb >> 9);
    if ((bb >> 7) & FileMask.notA != 0) attacks |= (bb >> 7);
    if ((bb >> 1) & FileMask.notH != 0) attacks |= (bb >> 1);
    if (bb << 8 != 0) attacks |= bb << 8;
    if ((bb << 9) & FileMask.notA != 0) attacks |= (bb << 9);
    if ((bb << 7) & FileMask.notH != 0) attacks |= (bb << 7);
    if ((bb << 1) & FileMask.notA != 0) attacks |= (bb << 1);

    return attacks;
}

pub fn maskBishopAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const targetRank: i8 = @divFloor(@as(i8, square), 8);
    const targetFile: i8 = @mod(@as(i8, square), 8);

    // Northeast
    {
        var rank = targetRank + 1;
        var file = targetFile + 1;
        while (rank <= 6 and file <= 6) : ({
            rank += 1;
            file += 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Northwest
    {
        var rank = targetRank + 1;
        var file = targetFile - 1;
        while (rank <= 6 and file >= 1) : ({
            rank += 1;
            file -= 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Southeast
    {
        var rank = targetRank - 1;
        var file = targetFile + 1;
        while (rank >= 1 and file <= 6) : ({
            rank -= 1;
            file += 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Southwest
    {
        var rank = targetRank - 1;
        var file = targetFile - 1;
        while (rank >= 1 and file >= 1) : ({
            rank -= 1;
            file -= 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    return attacks;
}

pub fn bishopAttacksOTF(square: u6, block: u64) u64 {
    var attacks: u64 = 0;
    const targetRank: i8 = @divFloor(@as(i8, square), 8);
    const targetFile: i8 = @mod(@as(i8, square), 8);

    // Northeast
    {
        var rank = targetRank + 1;
        var file = targetFile + 1;
        while (rank <= 7 and file <= 7) : ({
            rank += 1;
            file += 1;
        }) {
            const sq = @as(u6, @intCast(rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // Northwest
    {
        var rank = targetRank + 1;
        var file = targetFile - 1;
        while (rank <= 7 and file >= 0) : ({
            rank += 1;
            file -= 1;
        }) {
            const sq = @as(u6, @intCast(rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // Southeast
    {
        var rank = targetRank - 1;
        var file = targetFile + 1;
        while (rank >= 0 and file <= 7) : ({
            rank -= 1;
            file += 1;
        }) {
            const sq = @as(u6, @intCast(rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // Southwest
    {
        var rank = targetRank - 1;
        var file = targetFile - 1;
        while (rank >= 0 and file >= 0) : ({
            rank -= 1;
            file -= 1;
        }) {
            const sq = @as(u6, @intCast(rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    return attacks;
}

pub fn maskRookAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const targetRank: i8 = @divFloor(@as(i8, square), 8);
    const targetFile: i8 = @mod(@as(i8, square), 8);

    // North
    {
        var rank = targetRank + 1;
        while (rank <= 6) : (rank += 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + targetFile));
        }
    }

    // South
    {
        var rank = targetRank - 1;
        while (rank >= 1) : (rank -= 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + targetFile));
        }
    }

    // East
    {
        var file = targetFile + 1;
        while (file <= 6) : (file += 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(targetRank * 8 + file));
        }
    }

    // West
    {
        var file = targetFile - 1;
        while (file >= 1) : (file -= 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(targetRank * 8 + file));
        }
    }

    return attacks;
}

pub fn rookAttacksOTF(square: u6, block: u64) u64 {
    var attacks: u64 = 0;
    const targetRank: i8 = @divFloor(@as(i8, square), 8);
    const targetFile: i8 = @mod(@as(i8, square), 8);

    // North
    {
        var rank = targetRank + 1;
        while (rank <= 7) : (rank += 1) {
            const sq = @as(u6, @intCast(rank * 8 + targetFile));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // South
    {
        var rank = targetRank - 1;
        while (rank >= 0) : (rank -= 1) {
            const sq = @as(u6, @intCast(rank * 8 + targetFile));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // East
    {
        var file = targetFile + 1;
        while (file <= 7) : (file += 1) {
            const sq = @as(u6, @intCast(targetRank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // West
    {
        var file = targetFile - 1;
        while (file >= 0) : (file -= 1) {
            const sq = @as(u6, @intCast(targetRank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    return attacks;
}

pub fn getBishopAttacks(square: u6, occupancy: u64, table: *const AttackTable) u64 {
    var occ = occupancy;
    occ &= table.bishopMasks[square];
    occ *%= board.Magic.bishopMagicNumbers[square];
    occ >>= @intCast(@as(u8, 64) - board.Magic.bishopRelevantBits[square]);
    return table.bishop[square][occ];
}

pub fn getRookAttacks(square: u6, occupancy: u64, table: *const AttackTable) u64 {
    var occ = occupancy;
    occ &= table.rookMasks[square];
    occ *%= board.Magic.rookMagicNumbers[square];
    occ >>= @intCast(@as(u8, 64) - board.Magic.rookRelevantBits[square]);
    return table.rook[square][occ];
}

pub fn isSquareAttacked(square: u6, side: board.Side, gameBoard: *const board.Board, table: *const AttackTable) bool {
    const pieceSide = if (side == .white) board.Piece.p else board.Piece.P;

    // Pawn attacks
    if ((table.pawn[@intFromEnum(side)][square] & gameBoard.bitboard[@intFromEnum(pieceSide)]) != 0) return true;

    // Knight attacks
    if ((table.knight[square] & gameBoard.bitboard[@intFromEnum(pieceSide) + 1]) != 0) return true;

    // Bishop attacks
    if ((getBishopAttacks(square, gameBoard.occupancy[2], table) & gameBoard.bitboard[@intFromEnum(pieceSide) + 2]) != 0) return true;

    // Rook attacks
    if ((getRookAttacks(square, gameBoard.occupancy[2], table) & gameBoard.bitboard[@intFromEnum(pieceSide) + 3]) != 0) return true;

    // Queen attacks
    if (((getRookAttacks(square, gameBoard.occupancy[2], table) | getBishopAttacks(square, gameBoard.occupancy[2], table)) & gameBoard.bitboard[@intFromEnum(pieceSide) + 4]) != 0) return true;

    // King attacks
    if ((table.king[square] & gameBoard.bitboard[@intFromEnum(pieceSide) + 5]) != 0) return true;

    return false;
}

pub fn printAttackedSquares(side: board.Side, game_board: *const board.Board, table: *const AttackTable) void {
    std.debug.print("\n", .{});
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            if (file == 0) std.debug.print("   {d} ", .{8 - rank});
            const is_attacked = isSquareAttacked(square, side, game_board, table);
            std.debug.print(" {d}", .{@intFromBool(is_attacked)});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n     a b c d e f g h\n\n", .{});
}
