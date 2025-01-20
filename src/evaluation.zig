const std = @import("std");
const board = @import("bitboard.zig");
const utils = @import("utils.zig");

// Modern piece values (in centipawns)
pub const MaterialScore = struct {
    // White pieces (positive scores)
    pub const whitePawn: i32 = 100;
    pub const whiteKnight: i32 = 320;
    pub const whiteBishop: i32 = 330;
    pub const whiteRook: i32 = 500;
    pub const whiteQueen: i32 = 900;
    pub const whiteKing: i32 = 20000;

    // Black pieces (negative scores)
    pub const blackPawn: i32 = -100;
    pub const blackKnight: i32 = -320;
    pub const blackBishop: i32 = -330;
    pub const blackRook: i32 = -500;
    pub const blackQueen: i32 = -900;
    pub const blackKing: i32 = -20000;

    pub fn getScore(piece: board.Piece) i32 {
        return switch (piece) {
            .P => MaterialScore.whitePawn,
            .N => MaterialScore.whiteKnight,
            .B => MaterialScore.whiteBishop,
            .R => MaterialScore.whiteRook,
            .Q => MaterialScore.whiteQueen,
            .K => MaterialScore.whiteKing,
            .p => MaterialScore.blackPawn,
            .n => MaterialScore.blackKnight,
            .b => MaterialScore.blackBishop,
            .r => MaterialScore.blackRook,
            .q => MaterialScore.blackQueen,
            .k => MaterialScore.blackKing,
        };
    }
};

// Modern positional scores based on recent engine analysis
pub const PositionalScore = struct {
    // Pawn positioning (emphasizes center control and advancement)
    pub const pawnTable = [64]i32{
        0, 0, 0, 0, 0, 0, 0, 0, // 8th rank
        100, 100, 100, 100, 100, 100, 100, 100, // 7th rank (promotion potential)
        50, 50, 50, 60, 60, 50, 50, 50, // 6th rank
        25, 25, 35, 45, 45, 35, 25, 25, // 5th rank
        10, 10, 20, 35, 35, 20, 10, 10, // 4th rank
        5, 5, 10, 20, 20, 10, 5, 5, // 3rd rank
        5, 5, 5, 0, 0, 5, 5, 5, // 2nd rank
        0, 0, 0, 0, 0, 0, 0, 0, // 1st rank
    };

    // Knight positioning (emphasizes centralization and outposts)
    pub const knightTable = [64]i32{
        -50, -10, -10, -10, -10, -10, -10, -50, // 8th rank
        -10, 0, 0, 0, 0, 0, 0, -10, // 7th rank
        -10, 0, 10, 15, 15, 10, 0, -10, // 6th rank
        -10, 5, 15, 20, 20, 15, 5, -10, // 5th rank
        -10, 5, 15, 20, 20, 15, 5, -10, // 4th rank
        -10, 0, 10, 15, 15, 10, 0, -10, // 3rd rank
        -10, 0, 0, 0, 0, 0, 0, -10, // 2nd rank
        -50, -10, -10, -10, -10, -10, -10, -50, // 1st rank
    };

    // Bishop positioning (emphasizes diagonals and fianchetto)
    pub const bishopTable = [64]i32{
        -20, -10, -10, -10, -10, -10, -10, -20, // 8th rank
        -10, 5, 0, 0, 0, 0, 5, -10, // 7th rank
        -10, 10, 10, 10, 10, 10, 10, -10, // 6th rank
        -10, 0, 10, 10, 10, 10, 0, -10, // 5th rank
        -10, 5, 5, 10, 10, 5, 5, -10, // 4th rank
        -10, 0, 5, 10, 10, 5, 0, -10, // 3rd rank
        -10, 0, 0, 0, 0, 0, 0, -10, // 2nd rank
        -20, -10, -10, -10, -10, -10, -10, -20, // 1st rank
    };

    // Rook positioning (emphasizes open files and 7th rank)
    pub const rookTable = [64]i32{
        0, 0, 0, 5, 5, 0, 0, 0, // 8th rank
        5, 10, 10, 10, 10, 10, 10, 5, // 7th rank
        -5, 0, 0, 0, 0, 0, 0, -5, // 6th rank
        -5, 0, 0, 0, 0, 0, 0, -5, // 5th rank
        -5, 0, 0, 0, 0, 0, 0, -5, // 4th rank
        -5, 0, 0, 0, 0, 0, 0, -5, // 3rd rank
        -5, 0, 0, 0, 0, 0, 0, -5, // 2nd rank
        0, 0, 0, 5, 5, 0, 0, 0, // 1st rank
    };

    // Queen positioning (emphasizes center control and development)
    pub const queenTable = [64]i32{
        -20, -10, -10, -5, -5, -10, -10, -20, // 8th rank
        -10, 0, 0, 0, 0, 0, 0, -10, // 7th rank
        -10, 0, 5, 5, 5, 5, 0, -10, // 6th rank
        -5, 0, 5, 5, 5, 5, 0, -5, // 5th rank
        0, 0, 5, 5, 5, 5, 0, -5, // 4th rank
        -10, 5, 5, 5, 5, 5, 0, -10, // 3rd rank
        -10, 0, 5, 0, 0, 0, 0, -10, // 2nd rank
        -20, -10, -10, -5, -5, -10, -10, -20, // 1st rank
    };

    // King positioning (middlegame - emphasizes safety and castling)
    pub const kingTable = [64]i32{
        20, 30, 10, 0, 0, 10, 30, 20, // 8th rank
        20, 20, 0, 0, 0, 0, 20, 20, // 7th rank
        -10, -20, -20, -20, -20, -20, -20, -10, // 6th rank
        -20, -30, -30, -40, -40, -30, -30, -20, // 5th rank
        -30, -40, -40, -50, -50, -40, -40, -30, // 4th rank
        -30, -40, -40, -50, -50, -40, -40, -30, // 3rd rank
        -30, -40, -40, -50, -50, -40, -40, -30, // 2nd rank
        -30, -40, -40, -50, -50, -40, -40, -30, // 1st rank
    };

    // Get positional score for a piece at a given square
    pub fn getScore(piece: board.Piece, square: u6) i32 {
        // Mirror square for black pieces
        const actualSquare = if (piece.isWhite()) square else 63 - square;

        // Get base positional score
        const score = switch (piece) {
            .P, .p => pawnTable[actualSquare],
            .N, .n => knightTable[actualSquare],
            .B, .b => bishopTable[actualSquare],
            .R, .r => rookTable[actualSquare],
            .Q, .q => queenTable[actualSquare],
            .K, .k => kingTable[actualSquare],
        };

        // Return negative score for black pieces
        return if (piece.isWhite()) score else -score;
    }
};

/// Evaluates the current position
/// Returns a score in centipawns from white's perspective
pub fn evaluate(gameBoard: *const board.Board) i32 {
    var score: i32 = 0;

    // Calculate material and positional scores
    inline for (gameBoard.bitboard, 0..) |bitboard, pieceIndex| {
        var pieces = bitboard;
        const piece = @as(board.Piece, @enumFromInt(pieceIndex));

        while (pieces != 0) {
            const square = utils.getLSBindex(pieces);
            if (square >= 0) {
                // Add material score
                score += MaterialScore.getScore(piece);
                // Add positional score
                score += PositionalScore.getScore(piece, @intCast(square)); // TODO: detect endgame
            }
            pieces &= pieces - 1;
        }
    }

    // Return score from the perspective of the side to move
    return if (gameBoard.sideToMove == .white) score else -score;
}

pub fn getEvalText(score: i32) []const u8 {
    if (score > 0) {
        return "White is better";
    } else if (score < 0) {
        return "Black is better";
    } else {
        return "Equal position";
    }
}

pub fn getEvalNotation(score: i32) []const u8 {
    var buffer: [32]u8 = undefined;
    const absScore = @abs(score);
    const pawns = @as(f32, @floatFromInt(absScore)) / 100.0;

    return std.fmt.bufPrint(&buffer, "{s}{d:.2}", .{
        if (score >= 0) "+" else "-",
        pawns,
    }) catch "Error";
}
