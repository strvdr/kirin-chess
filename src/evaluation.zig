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
const board = @import("bitboard.zig");
const utils = @import("utils.zig");

// Modern piece values (in centipawns)
pub const MaterialScore = struct {
    // Use comptime to ensure these are computed at compile time
    pub const values = [12]i32{
        100, // White Pawn
        320, // White Knight
        330, // White Bishop
        500, // White Rook
        900, // White Queen
        20000, // White King
        -100, // Black Pawn
        -320, // Black Knight
        -330, // Black Bishop
        -500, // Black Rook
        -900, // Black Queen
        -20000, // Black King
    };

    pub inline fn getScore(piece: board.Piece) i32 {
        return values[@intFromEnum(piece)];
    }
};

// Modern positional scores based on recent engine analysis
pub const PositionalScore = struct {
    // Compile-time initialized tables
    const pawnTable = init: {
        var table: [64]i32 = undefined;
        const base = [8]i32{ 0, 5, 5, 0, 5, 10, 50, 0 };
        const bonus = [8]i32{ 0, 0, 10, 20, 30, 40, 50, 0 };

        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            const center_file_bonus: i32 = if (file == 3 or file == 4) 10 else 0;
            table[sq] = base[@intCast(rank)] + bonus[@intCast(rank)] + center_file_bonus;
        }
        break :init table;
    };

    const knightTable = init: {
        var table: [64]i32 = undefined;
        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            // Calculate distance to center squares
            const file_dist = @min(@abs(file - 3), @abs(file - 4));
            const rank_dist = @min(@abs(rank - 3), @abs(rank - 4));
            const center_dist: i32 = @max(file_dist, rank_dist);
            table[sq] = 20 - (center_dist * 5);
        }
        break :init table;
    };

    const bishopTable = init: {
        var table: [64]i32 = undefined;
        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            // Favor diagonals and center control
            const diagonal_bonus: i32 = if (file == rank or file == (7 - rank)) 15 else 0;
            const center_control: i32 = if ((rank == 3 or rank == 4) and (file == 3 or file == 4)) 10 else 0;
            table[sq] = diagonal_bonus + center_control;
        }
        break :init table;
    };

    const rookTable = init: {
        var table: [64]i32 = undefined;
        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            // Bonus for 7th rank and open files
            const seventh_rank_bonus: i32 = if (rank == 6 or rank == 1) 20 else 0;
            const file_bonus: i32 = if (file == 0 or file == 7) 10 else 0;
            table[sq] = seventh_rank_bonus + file_bonus;
        }
        break :init table;
    };

    const queenTable = init: {
        var table: [64]i32 = undefined;
        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            // Center control and safe squares
            const file_dist = @min(@abs(file - 3), @abs(file - 4));
            const rank_dist = @min(@abs(rank - 3), @abs(rank - 4));
            const center_dist: i32 = @max(file_dist, rank_dist);
            table[sq] = 15 - (center_dist * 3);
        }
        break :init table;
    };

    const kingTable = init: {
        var table: [64]i32 = undefined;
        for (0..64) |sq| {
            const rank: i32 = @intCast(sq / 8);
            const file: i32 = @intCast(sq % 8);
            // Encourage castling and king safety
            const castle_bonus: i32 = if ((file <= 2 or file >= 6) and rank == 0) 30 else 0;
            const back_rank_bonus: i32 = if (rank == 0) 20 else -20 * rank;
            table[sq] = castle_bonus + back_rank_bonus;
        }
        break :init table;
    };

    // Use inline for better performance
    pub inline fn getScore(piece: board.Piece, square: u6, is_endgame: bool) i32 {
        // Mirror square for black pieces
        const actualSquare = if (piece.isWhite()) square else 63 - square;

        // Get base positional score using a fast lookup table
        const score = switch (piece) {
            .P, .p => pawnTable[actualSquare],
            .N, .n => knightTable[actualSquare],
            .B, .b => bishopTable[actualSquare],
            .R, .r => rookTable[actualSquare],
            .Q, .q => queenTable[actualSquare],
            .K, .k => if (is_endgame)
                @divFloor(kingTable[actualSquare], 2) // Less important in endgame
            else
                kingTable[actualSquare],
        };

        // Return negative score for black pieces
        return if (piece.isWhite()) score else -score;
    }
};

/// Fast inline function to detect endgame
pub inline fn isEndgame(gameBoard: *const board.Board) bool {
    // Consider it endgame if:
    // 1. No queens or
    // 2. Only one queen and no other major pieces or
    // 3. Less than 3 minor pieces per side
    const white_queen = gameBoard.bitboard[@intFromEnum(board.Piece.Q)];
    const black_queen = gameBoard.bitboard[@intFromEnum(board.Piece.q)];
    const white_rooks = gameBoard.bitboard[@intFromEnum(board.Piece.R)];
    const black_rooks = gameBoard.bitboard[@intFromEnum(board.Piece.r)];

    const queens = utils.countBits(white_queen | black_queen);
    if (queens == 0) return true;

    const major_pieces = queens + utils.countBits(white_rooks | black_rooks);
    return major_pieces <= 1;
}

/// Evaluates the current position
/// Returns a score in centipawns from white's perspective
pub fn evaluate(gameBoard: *const board.Board) i32 {
    var score: i32 = 0;
    const is_endgame = isEndgame(gameBoard);

    // Use inline for to unroll the loop at compile time
    inline for (gameBoard.bitboard, 0..) |bitboard, pieceIndex| {
        var pieces = bitboard;
        const piece = @as(board.Piece, @enumFromInt(pieceIndex));

        while (pieces != 0) {
            const square = utils.getLSBindex(pieces);
            if (square >= 0) {
                // Add material score
                score += MaterialScore.getScore(piece);
                // Add positional score
                score += PositionalScore.getScore(piece, @intCast(square), is_endgame);
            }
            pieces &= pieces - 1; // Fast bit clear
        }
    }

    return if (gameBoard.sideToMove == .white) score else -score;
}

/// Formats evaluation text for display
pub fn getEvalText(score: i32) []const u8 {
    return if (score > 100)
        "White is better"
    else if (score < -100)
        "Black is better"
    else
        "Equal position";
}

/// Formats evaluation notation (e.g. "+1.5" or "-0.5")
pub fn getEvalNotation(score: i32) []const u8 {
    var buffer: [32]u8 = undefined;
    const absScore = @abs(score);
    const pawns = @as(f32, @floatFromInt(absScore)) / 100.0;

    return std.fmt.bufPrint(&buffer, "{s}{d:.2}", .{
        if (score >= 0) "+" else "-",
        pawns,
    }) catch "Error";
}
