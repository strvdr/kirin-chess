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
    pub const not_a: u64 = 18374403900871474942;
    pub const not_h: u64 = 9187201950435737471;
    pub const not_hg: u64 = 4557430888798830399;
    pub const not_ab: u64 = 18229723555195321596;
};

// Pre-calculated attack tables
pub const AttackTable = struct {
    pawn: [2][64]u64 = undefined, // [side][square]
    knight: [64]u64 = undefined, // [square]
    king: [64]u64 = undefined, // [square]
    bishop_masks: [64]u64 = undefined,
    rook_masks: [64]u64 = undefined,
    bishop: [64][512]u64 = undefined, // [square][magic_index]
    rook: [64][4096]u64 = undefined, // [square][magic_index]

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
                self.bishop_masks[square] = maskBishopAttacks(square);
                const mask = self.bishop_masks[square];
                const bits = utils.countBits(mask);
                const occupancy_indices = @as(u64, 1) << bits;

                for (0..occupancy_indices) |idx| {
                    const index = @as(u12, @intCast(idx));
                    const occupancy = utils.setOccupancy(index, bits, mask);
                    const magic_index =
                        (occupancy *% board.Magic.bishopMagicNumbers[square]) >>
                        @intCast(@as(u8, 64) - board.Magic.bishopRelevantBits[square]);
                    self.bishop[square][magic_index] = bishopAttacksOTF(square, occupancy);
                }
            } else {
                self.rook_masks[square] = maskRookAttacks(square);
                const mask = self.rook_masks[square];
                const bits = utils.countBits(mask);
                const occupancy_indices = @as(u64, 1) << bits;

                for (0..occupancy_indices) |idx| {
                    const index = @as(u12, @intCast(idx));
                    const occupancy = utils.setOccupancy(index, bits, mask);
                    const magic_index =
                        (occupancy *% board.Magic.rookMagicNumbers[square]) >>
                        @intCast(@as(u8, 64) - board.Magic.rookRelevantBits[square]);
                    self.rook[square][magic_index] = rookAttacksOTF(square, occupancy);
                }
            }
        }
    }
};

fn maskPawnAttacks(side: board.Side, square: u6) u64 {
    var attacks: u64 = 0;
    const bb: u64 = @as(u64, 1) << square;

    switch (side) {
        .white => {
            if ((bb << 7) & FileMask.not_a != 0) attacks |= bb << 7;
            if ((bb << 9) & FileMask.not_h != 0) attacks |= bb << 9;
        },
        .black => {
            if ((bb >> 7) & FileMask.not_h != 0) attacks |= bb >> 7;
            if ((bb >> 9) & FileMask.not_a != 0) attacks |= bb >> 9;
        },
        .both => {},
    }

    return attacks;
}

fn maskKnightAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const bb: u64 = @as(u64, 1) << square;

    if ((bb >> 17) & FileMask.not_h != 0) attacks |= bb >> 17;
    if ((bb >> 15) & FileMask.not_a != 0) attacks |= bb >> 15;
    if ((bb >> 10) & FileMask.not_hg != 0) attacks |= bb >> 10;
    if ((bb >> 6) & FileMask.not_ab != 0) attacks |= bb >> 6;
    if ((bb << 17) & FileMask.not_a != 0) attacks |= bb << 17;
    if ((bb << 15) & FileMask.not_h != 0) attacks |= bb << 15;
    if ((bb << 10) & FileMask.not_ab != 0) attacks |= bb << 10;
    if ((bb << 6) & FileMask.not_hg != 0) attacks |= bb << 6;

    return attacks;
}

fn maskKingAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const bb: u64 = @as(u64, 1) << square;

    if (bb >> 8 != 0) attacks |= bb >> 8;
    if ((bb >> 9) & FileMask.not_h != 0) attacks |= bb >> 9;
    if ((bb >> 7) & FileMask.not_a != 0) attacks |= bb >> 7;
    if ((bb >> 1) & FileMask.not_h != 0) attacks |= bb >> 1;
    if (bb << 8 != 0) attacks |= bb << 8;
    if ((bb << 9) & FileMask.not_a != 0) attacks |= bb << 9;
    if ((bb << 7) & FileMask.not_h != 0) attacks |= bb << 7;
    if ((bb << 1) & FileMask.not_a != 0) attacks |= bb << 1;

    return attacks;
}

fn maskBishopAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const target_rank: i8 = @divFloor(@as(i8, square), 8);
    const target_file: i8 = @mod(@as(i8, square), 8);

    // Northeast
    {
        var rank = target_rank + 1;
        var file = target_file + 1;
        while (rank <= 6 and file <= 6) : ({
            rank += 1;
            file += 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Northwest
    {
        var rank = target_rank + 1;
        var file = target_file - 1;
        while (rank <= 6 and file >= 1) : ({
            rank += 1;
            file -= 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Southeast
    {
        var rank = target_rank - 1;
        var file = target_file + 1;
        while (rank >= 1 and file <= 6) : ({
            rank -= 1;
            file += 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    // Southwest
    {
        var rank = target_rank - 1;
        var file = target_file - 1;
        while (rank >= 1 and file >= 1) : ({
            rank -= 1;
            file -= 1;
        }) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + file));
        }
    }

    return attacks;
}

fn bishopAttacksOTF(square: u6, block: u64) u64 {
    var attacks: u64 = 0;
    const target_rank: i8 = @divFloor(@as(i8, square), 8);
    const target_file: i8 = @mod(@as(i8, square), 8);

    // Northeast
    {
        var rank = target_rank + 1;
        var file = target_file + 1;
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
        var rank = target_rank + 1;
        var file = target_file - 1;
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
        var rank = target_rank - 1;
        var file = target_file + 1;
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
        var rank = target_rank - 1;
        var file = target_file - 1;
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

fn maskRookAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const target_rank: i8 = @divFloor(@as(i8, square), 8);
    const target_file: i8 = @mod(@as(i8, square), 8);

    // North
    {
        var rank = target_rank + 1;
        while (rank <= 6) : (rank += 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + target_file));
        }
    }

    // South
    {
        var rank = target_rank - 1;
        while (rank >= 1) : (rank -= 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(rank * 8 + target_file));
        }
    }

    // East
    {
        var file = target_file + 1;
        while (file <= 6) : (file += 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(target_rank * 8 + file));
        }
    }

    // West
    {
        var file = target_file - 1;
        while (file >= 1) : (file -= 1) {
            attacks |= @as(u64, 1) << @as(u6, @intCast(target_rank * 8 + file));
        }
    }

    return attacks;
}

fn rookAttacksOTF(square: u6, block: u64) u64 {
    var attacks: u64 = 0;
    const target_rank: i8 = @divFloor(@as(i8, square), 8);
    const target_file: i8 = @mod(@as(i8, square), 8);

    // North
    {
        var rank = target_rank + 1;
        while (rank <= 7) : (rank += 1) {
            const sq = @as(u6, @intCast(rank * 8 + target_file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // South
    {
        var rank = target_rank - 1;
        while (rank >= 0) : (rank -= 1) {
            const sq = @as(u6, @intCast(rank * 8 + target_file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // East
    {
        var file = target_file + 1;
        while (file <= 7) : (file += 1) {
            const sq = @as(u6, @intCast(target_rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    // West
    {
        var file = target_file - 1;
        while (file >= 0) : (file -= 1) {
            const sq = @as(u6, @intCast(target_rank * 8 + file));
            attacks |= @as(u64, 1) << sq;
            if (((@as(u64, 1) << sq) & block) != 0) break;
        }
    }

    return attacks;
}

pub fn getBishopAttacks(square: u6, occupancy: u64, table: *const AttackTable) u64 {
    var occ = occupancy;
    occ &= table.bishop_masks[square];
    occ *%= board.Magic.bishopMagicNumbers[square];
    occ >>= @intCast(64 - board.Magic.bishopRelevantBits[square]);
    return table.bishop[square][occ];
}

pub fn getRookAttacks(square: u6, occupancy: u64, table: *const AttackTable) u64 {
    var occ = occupancy;
    occ &= table.rook_masks[square];
    occ *%= board.Magic.rookMagicNumbers[square];
    occ >>= @intCast(64 - board.Magic.rookRelevantBits[square]);
    return table.rook[square][occ];
}

pub fn isSquareAttacked(square: u6, side: board.Side, game_board: *const board.Board, table: *const AttackTable) bool {
    const piece_side = if (side == .white) board.Piece else board.Piece.lowercase();

    // Pawn attacks
    if ((table.pawn[@intFromEnum(!side)][square] & game_board.piece_bb[piece_side.P]) != 0) return true;

    // Knight attacks
    if ((table.knight[square] & game_board.piece_bb[piece_side.N]) != 0) return true;

    // Bishop attacks
    if ((getBishopAttacks(square, game_board.occupancy[2], table) & game_board.piece_bb[piece_side.B]) != 0) return true;

    // Rook attacks
    if ((getRookAttacks(square, game_board.occupancy[2], table) & game_board.piece_bb[piece_side.R]) != 0) return true;

    // Queen attacks
    if (((getRookAttacks(square, game_board.occupancy[2], table) | (getBishopAttacks(square, game_board.occupancy[2], table))) & game_board.piece_bb[piece_side.Q]) != 0) return true;

    // King attacks
    if ((table.king[square] & game_board.piece_bb[piece_side.K]) != 0) return true;

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
