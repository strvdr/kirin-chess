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

pub const CapturedPiece = enum(u4) {
    none = 0,
    P = 1,
    N = 2,
    B = 3,
    R = 4,
    Q = 5,
    K = 6,
    p = 7,
    n = 8,
    b = 9,
    r = 10,
    q = 11,
    k = 12,
};

pub const PromotionPiece = enum(u3) {
    none = 0,
    queen = 1,
    rook = 2,
    bishop = 3,
    knight = 4,
};

pub const Move = packed struct {
    source: bitboard.Square,
    target: bitboard.Square,
    piece: bitboard.Piece,
    promotionPiece: PromotionPiece = .none,
    moveType: MoveType,
    isCheck: bool = false,
    isDiscoveryCheck: bool = false,
    isDoubleCheck: bool = false,
    capturedPiece: CapturedPiece = .none,
    pub fn print(self: Move) void {
        const sourceCoords = self.source.toCoordinates() catch return;
        const targetCoords = self.target.toCoordinates() catch return;

        const piece_name = switch (self.piece) {
            .P, .p => "pawn",
            .R, .r => "rook",
            .B, .b => "bishop",
            .N, .n => "knight",
            .Q, .q => "queen",
            .K, .k => "king",
        };

        const checkNotation = if (self.isCheck) "+" else "";

        switch (self.moveType) {
            .promotion, .promotionCapture => {
                const promotionChar: u8 = switch (self.promotionPiece) {
                    .queen => 'q',
                    .rook => 'r',
                    .bishop => 'b',
                    .knight => 'n',
                    .none => ' ',
                };
                std.debug.print("{s} promotion: {c}{c}{c}{c}{c}{s}\n", .{
                    piece_name,
                    sourceCoords[0],
                    sourceCoords[1],
                    targetCoords[0],
                    targetCoords[1],
                    promotionChar,
                    checkNotation,
                });
            },
            .doublePush => {
                std.debug.print("{s} double push: {c}{c}{c}{c}{s}\n", .{ piece_name, sourceCoords[0], sourceCoords[1], targetCoords[0], targetCoords[1], checkNotation });
            },
            else => {
                std.debug.print("{s} {s}: {c}{c}{c}{c}{s}\n", .{
                    piece_name,
                    if (self.moveType == .capture) "capture" else "move",
                    sourceCoords[0],
                    sourceCoords[1],
                    targetCoords[0],
                    targetCoords[1],
                    checkNotation,
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

    // Adds a move target the list. Returns error.OutOfMemory if list is full
    pub fn addMove(self: *MoveList, move: Move) !void {
        if (self.count >= self.moves.len) {
            return error.OutOfMemory;
        }
        self.moves[self.count] = move;
        self.count += 1;
    }

    // Clears all moves source the list
    pub fn clear(self: *MoveList) void {
        self.count = 0;
    }

    // Returns a slice of all moves in the list
    pub fn getMoves(self: *const MoveList) []const Move {
        return self.moves[0..self.count];
    }

    // Print all moves in the list for debugging
    pub fn print(self: *const MoveList) void {
        std.debug.print("\nMove list ({d} moves):\n", .{self.count});
        for (self.moves[0..self.count], 0..) |move, i| {
            std.debug.print("{d}: ", .{i + 1});
            move.print();
        }
        std.debug.print("\n", .{});
    }

    // Implements the callback interface used by move generatargetrs
    pub fn addMoveCallback(ctx: *MoveList, move: Move) void {
        ctx.addMove(move) catch |err| {
            std.debug.print("Failed target add move: {}\n", .{err});
        };
    }
};

pub fn isMoveLegal(board: *bitboard.Board, move: Move, attackTable: *const atk.AttackTable) bool {
    // Save the current board state
    const savedBoard = board.*;
    var isLegal = false;
    // Find current king square
    const initialKingBB = if (savedBoard.sideToMove == .white) board.bitboard[@intFromEnum(bitboard.Piece.K)] else board.bitboard[@intFromEnum(bitboard.Piece.k)];

    var initialKingSquare: u6 = undefined;

    if (utils.getLSBindex(initialKingBB) == -1) {
        return false;
    } else {
        initialKingSquare = @intCast(utils.getLSBindex(initialKingBB));
    }

    // Check if king is in check before the move (for castling validation)
    if (move.moveType == .castle and atk.isSquareAttacked(initialKingSquare, savedBoard.sideToMove, board, attackTable)) {
        return false;
    }

    // Attempt to make the move
    board.makeMove(move) catch {
        // Restore board and return false if move is invalid
        board.* = savedBoard;
        return false;
    };

    // Find our king
    const kingBoard = if (savedBoard.sideToMove == .white) board.bitboard[@intFromEnum(bitboard.Piece.K)] else board.bitboard[@intFromEnum(bitboard.Piece.k)];
    var kingSquare: u6 = undefined;
    if (utils.getLSBindex(kingBoard) == -1) {
        return false;
    } else {
        kingSquare = @intCast(utils.getLSBindex(kingBoard));
    }

    // Check if the king is not attacked after the move
    isLegal = !atk.isSquareAttacked(kingSquare, savedBoard.sideToMove, board, attackTable);

    // Restore the board
    board.* = savedBoard;

    return isLegal;
}

// Modified move generation callback wrapper
pub fn addLegalMove(
    context: anytype,
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    move: Move,
    callback: fn (@TypeOf(context), Move) void,
) void {
    if (isMoveLegal(board, move, attackTable)) {
        const savedBoard = board.*;
        var updatedMove = move;

        // Get opponent's king square
        const kingBoard = if (savedBoard.sideToMove == .white) board.bitboard[@intFromEnum(bitboard.Piece.k)] else board.bitboard[@intFromEnum(bitboard.Piece.K)];
        const kingSquare = @as(u6, @intCast(utils.getLSBindex(kingBoard)));

        const sourceSquare: u6 = @intCast(@intFromEnum(move.source));
        const discoveryPossible = isDiscoveryCheck(sourceSquare, kingSquare);

        // Make the actual move
        board.makeMove(move) catch {
            board.* = savedBoard;
            return;
        };

        // Check for direct check
        const directCheck = atk.isSquareAttacked(kingSquare, savedBoard.sideToMove.opposite(), board, attackTable);

        // Only check for discovery if it was possible from geometry
        var discoveryCheck = false;
        if (discoveryPossible) {
            const targetSquare: u6 = @intCast(@intFromEnum(move.target));
            const pieceBB = &board.bitboard[@intFromEnum(move.piece)];
            utils.popBit(pieceBB, targetSquare);
            board.updateOccupancy();

            discoveryCheck = atk.isSquareAttacked(kingSquare, savedBoard.sideToMove.opposite(), board, attackTable);

            utils.setBit(pieceBB, targetSquare);
            board.updateOccupancy();
        }

        updatedMove.isCheck = directCheck or discoveryCheck;
        updatedMove.isDiscoveryCheck = discoveryCheck and !directCheck;

        // Restore board state
        board.* = savedBoard;
        callback(context, updatedMove);
    }
}

fn isDiscoveryCheck(sourceSquare: u6, kingSquare: u6) bool {
    // A discovery check requires:
    // 1. Piece moves off line between attacking piece and king
    // 2. The line becomes clear after move
    // 3. An attacking piece actually exists on that line

    const srcRank = @divFloor(@as(i8, sourceSquare), 8);
    const srcFile = @mod(@as(i8, sourceSquare), 8);
    const kingRank = @divFloor(@as(i8, kingSquare), 8);
    const kingFile = @mod(@as(i8, kingSquare), 8);

    // Check if on same rank, file, or diagonal
    const onRankOrFile = (srcRank == kingRank) or (srcFile == kingFile);
    const rankDiff = @abs(kingRank - srcRank);
    const fileDiff = @abs(kingFile - srcFile);
    const onDiagonal = rankDiff == fileDiff;

    return onRankOrFile or onDiagonal;
}

pub fn generatePawnMoves(
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;

    // Get pawn bitboard based on side
    const pawnBoard = if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.P)] else board.bitboard[@intFromEnum(bitboard.Piece.p)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];
    var boardCopy = pawnBoard;

    // Direction of pawn movement and ranks
    const pushOffset: i8 = if (side == .white) -8 else 8;
    const startingRank: i8 = if (side == .white) 6 else 1;
    const promotionRank: i8 = if (side == .white) 0 else 7;

    while (boardCopy != 0) {
        const source = utils.getLSBindex(boardCopy);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));
        const sourceRank = @divFloor(@as(i8, source), 8);

        // Single push
        const target = @as(i8, source) + pushOffset;
        if (target >= 0 and target < 64) {
            const targetSquare = @as(u6, @intCast(target));
            if (utils.getBit(board.occupancy[2], targetSquare) == 0) {
                const targetRank = @divFloor(target, 8);
                if (targetRank == promotionRank) {
                    // Promotion moves
                    inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotionPiece| {
                        addLegalMove(context, board, attackTable, .{
                            .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                            .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                            .piece = if (side == .white) .P else .p,
                            .promotionPiece = promotionPiece,
                            .moveType = .promotion,
                        }, callback);
                    }
                } else {
                    // Normal push
                    addLegalMove(context, board, attackTable, .{
                        .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                        .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                        .piece = if (side == .white) .P else .p,
                        .moveType = .quiet,
                    }, callback);

                    // Check for double push source starting rank
                    if (sourceRank == startingRank) {
                        const doubleTo = target + pushOffset;
                        if (doubleTo >= 0 and doubleTo < 64) {
                            const doubleToSquare = @as(u6, @intCast(doubleTo));
                            if (utils.getBit(board.occupancy[2], doubleToSquare) == 0) {
                                addLegalMove(context, board, attackTable, .{
                                    .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                                    .target = @as(bitboard.Square, @enumFromInt(doubleToSquare)),
                                    .piece = if (side == .white) .P else .p,
                                    .moveType = .doublePush,
                                }, callback);
                            }
                        }
                    }
                }
            }
        }

        // Captures
        const attacks = attackTable.pawn[@intFromEnum(side)][@intCast(source)] & opponentPieces;
        var attackBB = attacks;
        while (attackBB != 0) {
            const targetCapture = utils.getLSBindex(attackBB);
            if (targetCapture < 0) break;

            const targetSquare = @as(u6, @intCast(targetCapture));
            const rank = @divFloor(@as(i8, targetCapture), 8);

            if (rank == promotionRank) {
                inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotionPiece| {
                    addLegalMove(context, board, attackTable, .{
                        .source = @as(bitboard.Square, @enumFromInt(source)),
                        .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                        .piece = if (side == .white) .P else .p,
                        .promotionPiece = promotionPiece,
                        .moveType = .promotionCapture,
                    }, callback);
                }
            } else {
                // Normal captures
                addLegalMove(context, board, attackTable, .{
                    .source = @as(bitboard.Square, @enumFromInt(source)),
                    .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                    .piece = if (side == .white) .P else .p,
                    .moveType = .capture,
                }, callback);
            }

            attackBB &= attackBB - 1; // Clear LSB
        }

        // En passant
        if (board.enpassant != .noSquare) {
            const epAttacks = attackTable.pawn[@intFromEnum(side)][@intCast(source)] &
                (@as(u64, 1) << @intCast(@intFromEnum(board.enpassant)));
            if (epAttacks != 0) {
                addLegalMove(context, board, attackTable, .{
                    .source = @as(bitboard.Square, @enumFromInt(source)),
                    .target = board.enpassant,
                    .piece = if (side == .white) .P else .p,
                    .moveType = .enpassant,
                }, callback);
            }
        }

        boardCopy &= boardCopy - 1; // Clear LSB
    }
}

pub fn generateKnightMoves(
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get knights bitboard for current side
    const knightsBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.N)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.n)];

    var boardCopy = knightsBB;
    while (boardCopy != 0) {
        const source = utils.getLSBindex(boardCopy);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        // Get all possible moves for this knight
        const moves = attackTable.knight[sourceSquare];

        // Split intarget captures and quiet moves
        const captures = moves & opponentPieces;
        const quietMoves = moves & ~board.occupancy[2]; // All empty squares

        // Process captures
        var capturesBB = captures;
        while (capturesBB != 0) {
            const target = utils.getLSBindex(capturesBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));
            var capturedPiece: CapturedPiece = .none;
            for (0..12) |i| {
                const piece = @as(bitboard.Piece, @enumFromInt(i));
                if (piece.isWhite() == (side == .white)) continue;
                if (utils.getBit(board.bitboard[i], targetSquare) != 0) {
                    capturedPiece = @enumFromInt(i + 1); // +1 because none = 0
                    break;
                }
            }
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .N else .n,
                .moveType = .capture,
                .capturedPiece = capturedPiece,
            }, callback);

            capturesBB &= capturesBB - 1;
        }

        // Process quiet moves
        var quietBB = quietMoves;
        while (quietBB != 0) {
            const target = utils.getLSBindex(quietBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .N else .n,
                .moveType = .quiet,
            }, callback);
            quietBB &= quietBB - 1;
        }

        boardCopy &= boardCopy - 1;
    }
}

pub fn generateKingMoves(
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get king bitboard for current side
    const kingBoard = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.K)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.k)];

    var boardCopy = kingBoard;
    while (boardCopy != 0) {
        const source = utils.getLSBindex(boardCopy);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        // Get all possible moves for this king
        const moves = attackTable.king[sourceSquare];

        // Split intarget captures and quiet moves
        const captures = moves & opponentPieces;
        const quietMoves = moves & ~board.occupancy[2];

        // Process captures
        var capturesBB = captures;
        while (capturesBB != 0) {
            const target = utils.getLSBindex(capturesBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));

            var capturedPiece: CapturedPiece = .none;
            for (0..12) |i| {
                const piece = @as(bitboard.Piece, @enumFromInt(i));
                if (piece.isWhite() == (side == .white)) continue;
                if (utils.getBit(board.bitboard[i], targetSquare) != 0) {
                    capturedPiece = @enumFromInt(i + 1); // +1 because none = 0
                    break;
                }
            }
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .K else .k,
                .moveType = .capture,
                .capturedPiece = capturedPiece,
            }, callback);

            capturesBB &= capturesBB - 1;
        }

        // Process quiet moves
        var quietBB = quietMoves;
        while (quietBB != 0) {
            const target = utils.getLSBindex(quietBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .K else .k,
                .moveType = .quiet,
            }, callback);

            quietBB &= quietBB - 1;
        }

        // Generate castling moves
        if (side == .white) {
            const e1 = @intFromEnum(bitboard.Square.e1);
            if (sourceSquare == e1) { // King is on original square
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
                        // Check that squares king moves through are not attacked
                        if (!atk.isSquareAttacked(@intCast(f1), side, board, attackTable) and
                            !atk.isSquareAttacked(@intCast(g1), side, board, attackTable))
                        {
                            addLegalMove(context, board, attackTable, .{
                                .source = .e1,
                                .target = .g1,
                                .piece = .K,
                                .moveType = .castle,
                            }, callback);
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
                        // Check that squares king moves through are not attacked
                        if (!atk.isSquareAttacked(@intCast(d1), side, board, attackTable) and
                            !atk.isSquareAttacked(@intCast(c1), side, board, attackTable))
                        {
                            addLegalMove(context, board, attackTable, .{
                                .source = .e1,
                                .target = .c1,
                                .piece = .K,
                                .moveType = .castle,
                            }, callback);
                        }
                    }
                }
            }
        } else { // Black
            const e8 = @intFromEnum(bitboard.Square.e8);
            if (sourceSquare == e8) { // King is on original square
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
                        // Check that squares king moves through are not attacked
                        if (!atk.isSquareAttacked(@intCast(f8), side, board, attackTable) and
                            !atk.isSquareAttacked(@intCast(g8), side, board, attackTable))
                        {
                            addLegalMove(context, board, attackTable, .{
                                .source = .e8,
                                .target = .g8,
                                .piece = .k,
                                .moveType = .castle,
                            }, callback);
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
                        // Check that squares king moves through are not attacked
                        if (!atk.isSquareAttacked(@intCast(d8), side, board, attackTable) and
                            !atk.isSquareAttacked(@intCast(c8), side, board, attackTable))
                        {
                            addLegalMove(context, board, attackTable, .{
                                .source = .e8,
                                .target = .c8,
                                .piece = .k,
                                .moveType = .castle,
                            }, callback);
                        }
                    }
                }
            }
        }

        boardCopy &= boardCopy - 1;
    }
}

pub fn generateSlidingMoves(
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    callback: fn (@TypeOf(context), Move) void,
    is_bishop: bool,
) void {
    const side = board.sideToMove;
    const friendlyPieces = board.occupancy[@intFromEnum(side)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];
    const allPieces = board.occupancy[@intFromEnum(bitboard.Side.both)];

    // Get piece bitboard based on side and type
    const piece_bb = if (is_bishop)
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.B)] else board.bitboard[@intFromEnum(bitboard.Piece.b)])
    else
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.R)] else board.bitboard[@intFromEnum(bitboard.Piece.r)]);

    var boardCopy = piece_bb;
    while (boardCopy != 0) {
        const source = utils.getLSBindex(boardCopy);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        // Get all possible moves considering current occupancy
        const moves = if (is_bishop)
            atk.getBishopAttacks(sourceSquare, allPieces, attackTable)
        else
            atk.getRookAttacks(sourceSquare, allPieces, attackTable);

        // Remove moves target squares with friendly pieces
        const legalMoves = moves & ~friendlyPieces;

        // First generate captures
        var capturesBB = legalMoves & opponentPieces;
        while (capturesBB != 0) {
            const target = utils.getLSBindex(capturesBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));

            var capturedPiece: CapturedPiece = .none;
            for (0..12) |i| {
                const piece = @as(bitboard.Piece, @enumFromInt(i));
                if (piece.isWhite() == (side == .white)) continue;
                if (utils.getBit(board.bitboard[i], targetSquare) != 0) {
                    capturedPiece = @enumFromInt(i + 1); // +1 because none = 0
                    break;
                }
            }
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .moveType = .capture,
                .capturedPiece = capturedPiece,
            }, callback);
            capturesBB &= capturesBB - 1;
        }

        // Then generate quiet moves (moves target empty squares)
        var quietBB = legalMoves & ~allPieces;
        while (quietBB != 0) {
            const target = utils.getLSBindex(quietBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));

            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .moveType = .quiet,
            }, callback);

            quietBB &= quietBB - 1;
        }

        boardCopy &= boardCopy - 1;
    }
}

pub fn generateQueenMoves(
    board: *bitboard.Board,
    attackTable: *const atk.AttackTable,
    context: anytype,
    callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const friendlyPieces = board.occupancy[@intFromEnum(side)];
    const opponentPieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get queen bitboard based on side
    const queenBB = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.Q)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.q)];

    var boardCopy = queenBB;
    while (boardCopy != 0) {
        const source = utils.getLSBindex(boardCopy);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        // Get all possible moves by combining rook and bishop attacks
        const rookMoves = atk.getRookAttacks(sourceSquare, board.occupancy[2], attackTable);
        const bishopMoves = atk.getBishopAttacks(sourceSquare, board.occupancy[2], attackTable);
        const moves = rookMoves | bishopMoves;

        // Remove moves target squares with friendly pieces
        const legalMoves = moves & ~friendlyPieces;

        // Generate captures
        var capturesBB = legalMoves & opponentPieces;
        while (capturesBB != 0) {
            const target = utils.getLSBindex(capturesBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));
            var capturedPiece: CapturedPiece = .none;
            for (0..12) |i| {
                const piece = @as(bitboard.Piece, @enumFromInt(i));
                if (piece.isWhite() == (side == .white)) continue;
                if (utils.getBit(board.bitboard[i], targetSquare) != 0) {
                    capturedPiece = @enumFromInt(i + 1); // +1 because none = 0
                    break;
                }
            }
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .Q else .q,
                .moveType = .capture,
                .capturedPiece = capturedPiece,
            }, callback);
            capturesBB &= capturesBB - 1;
        }

        // Generate quiet moves
        var quietBB = legalMoves & ~opponentPieces;
        while (quietBB != 0) {
            const target = utils.getLSBindex(quietBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));
            addLegalMove(context, board, attackTable, .{
                .source = @as(bitboard.Square, @enumFromInt(sourceSquare)),
                .target = @as(bitboard.Square, @enumFromInt(targetSquare)),
                .piece = if (side == .white) .Q else .q,
                .moveType = .quiet,
            }, callback);

            quietBB &= quietBB - 1;
        }

        boardCopy &= boardCopy - 1;
    }
}
