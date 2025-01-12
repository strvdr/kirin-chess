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
    castle,
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
        const fromCoords = self.from.toCoordinates() catch return;
        const toCoords = self.to.toCoordinates() catch return;

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
                    fromCoords[0],
                    fromCoords[1],
                    toCoords[0],
                    toCoords[1],
                    promotionChar,
                });
            },
            .doublePush => {
                std.debug.print("{s} double push: {c}{c}{c}{c}\n", .{
                    piece_name,
                    fromCoords[0],
                    fromCoords[1],
                    toCoords[0],
                    toCoords[1],
                });
            },
            else => {
                std.debug.print("{s} {s}: {c}{c}{c}{c}\n", .{
                    piece_name,
                    if (self.moveType == .capture) "capture" else "move",
                    fromCoords[0],
                    fromCoords[1],
                    toCoords[0],
                    toCoords[1],
                });
            },
        }
    }
};

pub const MoveList = struct {
    moves: [256]Move = undefined,
    count: usize = 0,

    pub fn init() MoveList {
        return .{};
    }

    /// Adds a move to the list. Returns error.OutOfMemory if list is full
    pub fn addMove(self: *MoveList, move: Move) !void {
        if (self.count >= self.moves.len) {
            return error.OutOfMemory;
        }
        self.moves[self.count] = move;
        self.count += 1;
    }

    /// Removes and returns the last move added. Returns null if list is empty
    pub fn popMove(self: *MoveList) ?Move {
        if (self.count == 0) return null;
        self.count -= 1;
        return self.moves[self.count];
    }

    /// Clears all moves from the list
    pub fn clear(self: *MoveList) void {
        self.count = 0;
    }

    /// Returns a slice of all moves in the list
    pub fn getMoves(self: *const MoveList) []const Move {
        return self.moves[0..self.count];
    }

    /// Returns true if the list contains no moves
    pub fn isEmpty(self: *const MoveList) bool {
        return self.count == 0;
    }

    /// Returns true if the list is full
    pub fn isFull(self: *const MoveList) bool {
        return self.count >= self.moves.len;
    }

    /// Print all moves in the list for debugging
    pub fn print(self: *const MoveList) void {
        std.debug.print("\nMove list ({d} moves):\n", .{self.count});
        for (self.moves[0..self.count], 0..) |move, i| {
            std.debug.print("{d}: ", .{i + 1});
            move.print();
        }
        std.debug.print("\n", .{});
    }

    /// Implements the callback interface used by move generators
    pub fn addMoveCallback(ctx: *MoveList, move: Move) void {
        ctx.addMove(move) catch |err| {
            std.debug.print("Failed to add move: {}\n", .{err});
        };
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
    const pushOffset: i8 = if (side == .white) -8 else 8;
    const startingRank: i8 = if (side == .white) 6 else 1;
    const promotionRank: i8 = if (side == .white) 0 else 7;

    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));
        const fromRank = @divFloor(@as(i8, from), 8);

        // Single push
        const to = @as(i8, from) + pushOffset;
        if (to >= 0 and to < 64) {
            const toSquare = @as(u6, @intCast(to));
            if (utils.getBit(board.occupancy[2], toSquare) == 0) {
                const toRank = @divFloor(to, 8);
                if (toRank == promotionRank) {
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

                    // Check for double push from starting rank
                    if (fromRank == startingRank) {
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

        // Generate castling moves
        if (side == .white) {
            const e1 = @intFromEnum(bitboard.Square.e1);
            if (fromSquare == e1) { // King is on original square
                // Check kingside castling
                if (board.castling.whiteKingside) {
                    const f1 = @intFromEnum(bitboard.Square.f1);
                    const g1 = @intFromEnum(bitboard.Square.g1);
                    const h1 = @intFromEnum(bitboard.Square.h1);

                    // Check if path is clear
                    if (utils.getBit(board.occupancy[2], f1) == 0 and
                        utils.getBit(board.occupancy[2], g1) == 0 and
                        utils.getBit(board.bitboard[@intFromEnum(bitboard.Piece.R)], h1) == 1)
                    {
                        if (!atk.isSquareAttacked(@intCast(e1), side, board, attackTable)) {
                            // Check that squares king moves through are not attacked
                            if (!atk.isSquareAttacked(@intCast(f1), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(g1), side, board, attackTable))
                            {
                                callback(context, .{
                                    .from = .e1,
                                    .to = .g1,
                                    .piece = .K,
                                    .moveType = .castle,
                                });
                            }
                        }
                    }
                }

                // Check queenside castling
                if (board.castling.whiteQueenside) {
                    const d1 = @intFromEnum(bitboard.Square.d1);
                    const c1 = @intFromEnum(bitboard.Square.c1);
                    const b1 = @intFromEnum(bitboard.Square.b1);
                    const a1 = @intFromEnum(bitboard.Square.a1);

                    // Check if path is clear
                    if (utils.getBit(board.occupancy[2], d1) == 0 and
                        utils.getBit(board.occupancy[2], c1) == 0 and
                        utils.getBit(board.occupancy[2], b1) == 0 and
                        utils.getBit(board.bitboard[@intFromEnum(bitboard.Piece.R)], a1) == 1)
                    {
                        if (!atk.isSquareAttacked(@intCast(e1), side, board, attackTable)) {
                            // Check that squares king moves through are not attacked
                            if (!atk.isSquareAttacked(@intCast(d1), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(c1), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(b1), side, board, attackTable))
                            {
                                callback(context, .{
                                    .from = .e1,
                                    .to = .c1,
                                    .piece = .K,
                                    .moveType = .castle,
                                });
                            }
                        }
                    }
                }
            }
        } else { // Black
            const e8 = @intFromEnum(bitboard.Square.e8);
            if (fromSquare == e8) { // King is on original square
                // Check kingside castling
                if (board.castling.blackKingside) {
                    const f8 = @intFromEnum(bitboard.Square.f8);
                    const g8 = @intFromEnum(bitboard.Square.g8);
                    const h8 = @intFromEnum(bitboard.Square.h8);

                    // Check if path is clear
                    if (utils.getBit(board.occupancy[2], f8) == 0 and
                        utils.getBit(board.occupancy[2], g8) == 0 and
                        utils.getBit(board.bitboard[@intFromEnum(bitboard.Piece.r)], h8) == 1)
                    {
                        if (!atk.isSquareAttacked(@intCast(e8), side, board, attackTable)) {
                            // Check that squares king moves through are not attacked
                            if (!atk.isSquareAttacked(@intCast(f8), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(g8), side, board, attackTable))
                            {
                                callback(context, .{
                                    .from = .e8,
                                    .to = .g8,
                                    .piece = .k,
                                    .moveType = .castle,
                                });
                            }
                        }
                    }
                }

                // Check queenside castling
                if (board.castling.blackQueenside) {
                    const d8 = @intFromEnum(bitboard.Square.d8);
                    const c8 = @intFromEnum(bitboard.Square.c8);
                    const b8 = @intFromEnum(bitboard.Square.b8);
                    const a8 = @intFromEnum(bitboard.Square.a8);

                    // Check if path is clear
                    if (utils.getBit(board.occupancy[2], d8) == 0 and
                        utils.getBit(board.occupancy[2], c8) == 0 and
                        utils.getBit(board.occupancy[2], b8) == 0 and
                        utils.getBit(board.bitboard[@intFromEnum(bitboard.Piece.r)], a8) == 1)
                    {
                        if (!atk.isSquareAttacked(@intCast(e8), side, board, attackTable)) {
                            // Check that squares king moves through are not attacked
                            if (!atk.isSquareAttacked(@intCast(d8), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(c8), side, board, attackTable) and
                                !atk.isSquareAttacked(@intCast(b8), side, board, attackTable))
                            {
                                callback(context, .{
                                    .from = .e8,
                                    .to = .c8,
                                    .piece = .k,
                                    .moveType = .castle,
                                });
                            }
                        }
                    }
                }
            }
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
        var quietBB = legalMoves & ~opponentPieces;
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

pub fn generateQueenMoves(
    board: *const bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const friendlyPieces = board.occupancy[@intFromEnum(side)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get queen bitboard based on side
    const queenBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.Q)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.q)];

    var bbCopy = queenBB;
    while (bbCopy != 0) {
        const from = utils.getLSBindex(bbCopy);
        if (from < 0) break;
        const fromSquare = @as(u6, @intCast(from));

        // Get all possible moves by combining rook and bishop attacks
        const rookMoves = atk.getRookAttacks(fromSquare, board.occupancy[2], attackTable);
        const bishopMoves = atk.getBishopAttacks(fromSquare, board.occupancy[2], attackTable);
        const moves = rookMoves | bishopMoves;

        // Remove moves to squares with friendly pieces
        const legalMoves = moves & ~friendlyPieces;

        // Generate captures
        var capturesBB = legalMoves & opponentPieces;
        while (capturesBB != 0) {
            const to = utils.getLSBindex(capturesBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .Q else .q,
                .moveType = .capture,
            });

            capturesBB &= capturesBB - 1;
        }

        // Generate quiet moves
        var quietBB = legalMoves & ~opponentPieces;
        while (quietBB != 0) {
            const to = utils.getLSBindex(quietBB);
            if (to < 0) break;
            const toSquare = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(fromSquare)),
                .to = @as(bitboard.Square, @enumFromInt(toSquare)),
                .piece = if (side == .white) .Q else .q,
                .moveType = .quiet,
            });

            quietBB &= quietBB - 1;
        }

        bbCopy &= bbCopy - 1;
    }
}
