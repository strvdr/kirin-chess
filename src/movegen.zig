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
const bitboard = @import("bitboard.zig");
const utils = @import("utils.zig");
const atk = @import("attacks.zig");

pub const MoveType = enum(u3) {
    quiet,
    capture,
    promotion,
    promotionCapture,
    doublePush,
    enpassant,
};

pub const PromotionPiece = enum(u3) {
    none = 0,
    queen = 1,
    rook = 2,
    bishop = 3,
    knight = 4,
};

pub const Move = packed struct {
    from: bitboard.Square,
    to: bitboard.Square,
    piece: bitboard.Piece,
    promotionPiece: PromotionPiece = .none,
    moveType: MoveType,

    pub fn print(self: Move) void {
        const sourceCoords = self.from.toCoordinates() catch return;
        const targetCoords = self.to.toCoordinates() catch return;

        const piece_name = switch (self.piece) {
            .P, .p => "pawn",
            .R, .r => "rook",
            .B, .b => "bishop",
            .N, .n => "knight",
            .Q, .q => "queen",
            .K, .k => "king",
        };

        switch (self.moveType) {
            .promotion, .promotionCapture => {
                const promotionChar = bitboard.Piece.toPromotionChar(@as(bitboard.Piece, @enumFromInt(@intFromEnum(self.promotionPiece))));
                std.debug.print("{s} promotion: {c}{c}{c}{c}{c}\n", .{
                    piece_name,
                    sourceCoords[0],
                    sourceCoords[1],
                    targetCoords[0],
                    targetCoords[1],
                    promotionChar,
                });
            },
            .doublePush => {
                std.debug.print("{s} double push: {c}{c}{c}{c}\n", .{
                    piece_name,
                    sourceCoords[0],
                    sourceCoords[1],
                    targetCoords[0],
                    targetCoords[1],
                });
            },
            else => {
                std.debug.print("{s} {s}: {c}{c}{c}{c}\n", .{
                    piece_name,
                    if (self.moveType == .capture) "capture" else "move",
                    sourceCoords[0],
                    sourceCoords[1],
                    targetCoords[0],
                    targetCoords[1],
                });
            },
        }
    }
};

pub fn generatePawnMoves(
    board: *const bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;

    // Get pawn bitboard based on side
    const pawnBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.P)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.p)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];
    var bbCopy = pawnBB;

    // Direction of pawn movement and ranks
    const pushOffset: i8 = switch (side) {
        .white => 8,
        .black => -8,
        .both => unreachable,
    };

    const promotionRank: i8 = switch (side) {
        .white => 7,
        .black => 0,
        .both => unreachable,
    };

    const startingRank: i8 = switch (side) {
        .white => 6,
        .black => 1,
        .both => unreachable,
    };

    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));

        // Single push
        const to = @as(u6, @intCast(from)) + pushOffset;
        if (to >= 0 and to < 64) {
            const toSquare = @as(u6, @intCast(to));
            if (utils.getBit(board.occupancy[2], toSquare) == 0) {
                const rank = @divFloor(@as(i8, to), 8);
                if (rank == promotionRank) {
                    // Promotion moves
                    inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotionPiece| {
                        callback(context, .{
                            .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                            .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                            .piece = if (side == .white) .P else .p,
                            .promotionPiece = promotionPiece,
                            .moveType = .promotion,
                        });
                    }
                } else {
                    // Normal push
                    callback(context, .{
                        .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                        .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                        .piece = if (side == .white) .P else .p,
                        .moveType = .quiet,
                    });

                    // Double push
                    const currentRank = @divFloor(@as(i8, from), 8);
                    if (currentRank == startingRank) {
                        const doubleTo = to + pushOffset;
                        if (doubleTo >= 0 and doubleTo < 64) {
                            const doubleToSquare = @as(u6, @intCast(doubleTo));
                            if (utils.getBit(board.occupancy[2], doubleToSquare) == 0) {
                                callback(context, .{
                                    .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                                    .to = @as(bitboard.Square, @enumFromInt(doubleToSquare)),
                                    .piece = if (side == .white) .P else .p,
                                    .moveType = .doublePush,
                                });
                            }
                        }
                    }
                }
            }
        }

        // Captures
        const attacks = attackTable.pawn[@intFromEnum(side)][@intCast(from)] & opponentPieces;
        var attackBB = attacks;
        while (attackBB != 0) {
            const toCapture = utils.getLSBindex(attackBB);
            if (toCapture < 0) break;

            const toSquare = @as(u6, @intCast(toCapture));
            const rank = @divFloor(@as(i8, toCapture), 8);

            if (rank == promotionRank) {
                inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotionPiece| {
                    callback(context, .{
                        .from = @as(bitboard.Square, @enumFromInt(from)),
                        .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                        .piece = if (side == .white) .P else .p,
                        .promotionPiece = promotionPiece,
                        .moveType = .promotionCapture,
                    });
                }
            } else {
                // Normal captures
                callback(context, .{
                    .from = @as(bitboard.Square, @enumFromInt(from)),
                    .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                    .piece = if (side == .white) .P else .p,
                    .moveType = .capture,
                });
            }

            attackBB &= attackBB - 1; // Clear LSB
        }

        // En passant
        if (board.enpassant != .noSquare) {
            const epAttacks = attackTable.pawn[@intFromEnum(side)][@intCast(from)] &
                (@as(u64, 1) << @intCast(@intFromEnum(board.enpassant)));
            if (epAttacks != 0) {
                callback(context, .{
                    .from = @as(bitboard.Square, @enumFromInt(from)),
                    .to = board.enpassant,
                    .piece = if (side == .white) .P else .p,
                    .moveType = .enpassant,
                });
            }
        }

        bbCopy &= bbCopy - 1; // Clear LSB
    }
}

pub fn generateKnightMoves(
    board: *const bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get knights bitboard for current side
    const knightsBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.N)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.n)];

    var bbCopy = knightsBB;
    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));

        // Get all possible moves for this knight
        const moves = attackTable.knight[fromSquare];

        // Split into captures and quiet moves
        const captures = moves & opponentPieces;
        const quietMoves = moves & ~board.occupancy[2]; // All empty squares

        // Process captures
        var capturesBB = captures;
        while (capturesBB != 0) {
            const to = utils.getLSBindex(capturesBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .N else .n,
                .moveType = .capture,
            });

            capturesBB &= capturesBB - 1;
        }

        // Process quiet moves
        var quietBB = quietMoves;
        while (quietBB != 0) {
            const to = utils.getLSBindex(quietBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .N else .n,
                .moveType = .quiet,
            });

            quietBB &= quietBB - 1;
        }

        bbCopy &= bbCopy - 1;
    }
}

pub fn generateKingMoves(
    board: *const bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get king bitboard for current side
    const kingBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.K)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.k)];

    var bbCopy = kingBB;
    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));

        // Get all possible moves for this king
        const moves = attackTable.king[fromSquare];

        // Split into captures and quiet moves
        const captures = moves & opponentPieces;
        const quietMoves = moves & ~board.occupancy[2];

        // Process captures
        var capturesBB = captures;
        while (capturesBB != 0) {
            const to = utils.getLSBindex(capturesBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .K else .k,
                .moveType = .capture,
            });

            capturesBB &= capturesBB - 1;
        }

        // Process quiet moves
        var quietBB = quietMoves;
        while (quietBB != 0) {
            const to = utils.getLSBindex(quietBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .K else .k,
                .moveType = .quiet,
            });

            quietBB &= quietBB - 1;
        }

        bbCopy &= bbCopy - 1;
    }
}

pub fn generateSlidingMoves(
    board: *const bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
    is_bishop: bool,
) void {
    const side = board.sideToMove;
    const friendlyPieces = board.occupancy[@intFromEnum(side)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get piece bitboard based on side and type
    const piece_bb = if (is_bishop)
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.B)] else board.bitboard[@intFromEnum(bitboard.Piece.b)])
    else
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.R)] else board.bitboard[@intFromEnum(bitboard.Piece.r)]);

    var bbCopy = piece_bb;
    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));

        // Get all possible moves considering current occupancy
        const moves = if (is_bishop)
            atk.getBishopAttacks(fromSquare, board.occupancy[2], attackTable)
        else
            atk.getRookAttacks(fromSquare, board.occupancy[2], attackTable);

        // Remove moves to squares with friendly pieces
        const legalMoves = moves & ~friendlyPieces;

        // First generate captures
        var capturesBB = legalMoves & opponentPieces;
        while (capturesBB != 0) {
            const to = utils.getLSBindex(capturesBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .moveType = .capture,
            });

            capturesBB &= capturesBB - 1;
        }

        // Then generate quiet moves (moves to empty squares)
        var quietBB = legalMoves & ~opponentPieces; // Changed from board.occupancy[2]
        while (quietBB != 0) {
            const to = utils.getLSBindex(quietBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .moveType = .quiet,
            });

            quietBB &= quietBB - 1;
        }

        bbCopy &= bbCopy - 1;
    }
}
