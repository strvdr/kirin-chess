const std = @import("std");
const bitboard = @import("bitboard.zig");
const movegen = @import("movegen.zig");
const attacks = @import("attacks.zig");
const evaluation = @import("evaluation.zig");
const utils = @import("utils.zig");

// Constants for search
pub const INFINITY: i32 = 50000;
const MATE_SCORE: i32 = 49000;
const MATE_THRESHOLD: i32 = 48000;
const MAX_PLY: u8 = 64;
const NULL_MOVE_REDUCTION: u8 = 3;
const FUTILITY_MARGIN: i32 = 100;
const RAZOR_MARGIN: i32 = 300;
const LMR_MIN_DEPTH: u8 = 3;
const LMR_MIN_MOVES: u8 = 4;

// Transposition table entry types
const TTEntryType = enum(u2) {
    exact,
    alpha,
    beta,
};

const TTEntry = struct {
    key: u64,
    depth: u8,
    score: i32,
    entryType: TTEntryType,
    bestMove: ?movegen.Move,
};

// History heuristic table [piece][square]
const HistoryTable = struct {
    table: [12][64]i32 = [_][64]i32{[_]i32{0} ** 64} ** 12,

    pub fn update(self: *HistoryTable, piece: bitboard.Piece, square: u6, depth: u8) void {
        self.table[@intFromEnum(piece)][square] += @as(i32, depth) * @as(i32, depth);
    }

    pub fn get(self: *const HistoryTable, piece: bitboard.Piece, square: u6) i32 {
        return self.table[@intFromEnum(piece)][square];
    }
};

// Killer moves table [ply][slot]
const KillerMoves = struct {
    moves: [MAX_PLY][2]?movegen.Move = [_][2]?movegen.Move{[_]?movegen.Move{null} ** 2} ** MAX_PLY,

    pub fn update(self: *KillerMoves, move: movegen.Move, ply: u8) void {
        if (ply >= MAX_PLY) return;
        if (self.moves[ply][0] != move) {
            self.moves[ply][1] = self.moves[ply][0];
            self.moves[ply][0] = move;
        }
    }

    pub fn isKiller(self: *const KillerMoves, move: movegen.Move, ply: u8) bool {
        if (ply >= MAX_PLY) return false;
        return (self.moves[ply][0] == move or self.moves[ply][1] == move);
    }
};

pub const SearchInfo = struct {
    nodes: u64 = 0,
    depth: u8 = 0,
    bestMove: ?movegen.Move = null,
    shouldStop: bool = false,
    history: HistoryTable = HistoryTable{},
    killers: KillerMoves = KillerMoves{},
    pvLength: [MAX_PLY]u8 = [_]u8{0} ** MAX_PLY,
    pvTable: [MAX_PLY][MAX_PLY]movegen.Move = undefined,
};

// Function to score moves for ordering
fn scoreMoves(info: *SearchInfo, moves: []movegen.Move, ply: u8, ttMove: ?movegen.Move) void {
    for (moves) |*move| {
        var score: i32 = 0;

        // TT move gets highest priority
        if (ttMove != null and move.* == ttMove.?) {
            score = 2000000;
        }
        // Then captures, ordered by MVV-LVA
        else if (move.moveType == .capture or move.moveType == .promotionCapture) {
            score = 1000000 + scoreCapture(move.*);
        }
        // Then killer moves
        else if (info.killers.isKiller(move.*, ply)) {
            score = 900000;
        }
        // Finally history score
        else {
            score = info.history.get(move.piece, @intCast(@intFromEnum(move.target)));
        }

        // Store score in the unused fields of the move
        move.isDoubleCheck = (score > 0); // Using unused field to store score sign
        move.isDiscoveryCheck = (score < 0); // Using unused field for additional score info
    }
}

// Quiescence search to handle tactical sequences
fn quiescence(
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
    alpha_: i32,
    beta: i32,
    info: *SearchInfo,
) i32 {
    info.nodes += 1;
    if (info.shouldStop) return 0;

    var alpha = alpha_;
    const standPat = evaluation.evaluate(gameBoard);

    if (standPat >= beta) {
        return beta;
    }

    if (standPat > alpha) {
        alpha = standPat;
    }

    // Generate captures only
    var moveList = movegen.MoveList.init();
    generateCaptures(gameBoard, attackTable, &moveList);

    // Score and sort moves
    scoreMoves(info, moveList.getMovesMut(), 0, null);
    sortMoves(moveList.getMovesMut());

    const savedBoard = gameBoard.*;
    for (moveList.getMoves()) |move| {
        gameBoard.makeMove(move) catch {
            gameBoard.* = savedBoard;
            continue;
        };

        const score = -quiescence(gameBoard, attackTable, -beta, -alpha, info);
        gameBoard.* = savedBoard;

        if (score >= beta) {
            return beta;
        }
        if (score > alpha) {
            alpha = score;
        }
    }

    return alpha;
}

/// Check if a move gives check by actually making the move and checking
fn givesCheck(gameBoard: *const bitboard.Board, attackTable: *const attacks.AttackTable) bool {
    // Save the current side to move
    const originalSide = gameBoard.sideToMove;

    // Toggle side to view from opponent's perspective
    const side = if (originalSide == .white) bitboard.Side.black else bitboard.Side.white;

    // Find opponent's king
    const kingPiece = if (side == .white) bitboard.Piece.K else bitboard.Piece.k;
    const kingBoard = gameBoard.bitboard[@intFromEnum(kingPiece)];

    // If no king found, something is wrong with the board
    if (kingBoard == 0) return false;

    const kingSquare = @as(u6, @intCast(utils.getLSBindex(kingBoard)));

    // Check if king is attacked from the new position
    return attacks.isSquareAttacked(kingSquare, side, gameBoard, attackTable);
}

pub fn pvSearch(
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
    depth: u8,
    ply: u8,
    alpha_: i32,
    beta: i32,
    canNull: bool,
    info: *SearchInfo,
) !i32 {
    if (ply == 0) {
        std.debug.print("Search params - depth: {d}, ply: {d}, alpha: {d}, beta: {d}, canNull: {}\n", .{ depth, ply, alpha_, beta, canNull });
    }

    if (info.shouldStop) return 0;

    if (ply >= MAX_PLY - 1) {
        if (ply == 0) std.debug.print("Hit max ply\n", .{});
        return evaluation.evaluate(gameBoard);
    }

    const inCheck = isInCheck(gameBoard, attackTable);
    const isPv = beta - alpha_ > 1;

    if (ply == 0) {
        std.debug.print("Position info - inCheck: {}, isPv: {}\n", .{ inCheck, isPv });
    }

    var newDepth = depth;
    if (inCheck) {
        newDepth += 1;
        if (ply == 0) std.debug.print("Extending depth due to check. New depth: {d}\n", .{newDepth});
    }

    if (newDepth == 0) {
        if (ply == 0) std.debug.print("Starting quiescence search\n", .{});
        return quiescence(gameBoard, attackTable, alpha_, beta, info);
    }

    info.nodes += 1;
    if (info.nodes % 10000 == 0 and ply == 0) {
        std.debug.print("Nodes searched: {d}\n", .{info.nodes});
    }

    if (ply == 0) std.debug.print("Generating moves...\n", .{});

    var moveList = movegen.MoveList.init();
    generateAllMoves(gameBoard, attackTable, &moveList);

    if (ply == 0) std.debug.print("Generated {d} moves\n", .{moveList.count});

    if (moveList.count == 0) {
        if (inCheck) {
            if (ply == 0) std.debug.print("Checkmate\n", .{});
            return -MATE_SCORE + @as(i32, ply);
        }
        if (ply == 0) std.debug.print("Stalemate\n", .{});
        return 0;
    }

    var alpha = alpha_;
    var bestMove: ?movegen.Move = null;
    var moveCount: u8 = 0;

    scoreMoves(info, moveList.getMovesMut(), ply, bestMove);
    sortMoves(moveList.getMovesMut());

    const savedBoard = gameBoard.*;
    const nextPly = if (ply >= MAX_PLY - 2) ply else ply + 1;

    // Main move loop
    for (moveList.getMovesMut()) |move| {
        moveCount += 1;

        if (ply == 0) {
            std.debug.print("Searching move {d}/{d}: ", .{ moveCount, moveList.count });
            printMove(move);
            std.debug.print("\n", .{});
        }

        gameBoard.makeMove(move) catch |err| {
            if (ply == 0) {
                std.debug.print("Error making move: {any}\n", .{err});
            }
            gameBoard.* = savedBoard;
            continue;
        };

        var score: i32 = undefined;

        // For very shallow depths, don't use reductions
        var reduction: u8 = 0;
        const searchDepth = if (newDepth > 0) newDepth - 1 else 0;

        if (newDepth >= 2 and !isPv) { // Only try reductions at depth 2+
            if (moveCount >= LMR_MIN_MOVES and
                !inCheck and
                move.moveType != .capture and
                move.moveType != .promotionCapture)
            {
                reduction = if (moveCount >= 6) 1 else 0;
            }
        }

        // Perform the search based on position in move list and reduction
        if (moveCount == 1) {
            if (ply == 0) {
                std.debug.print("First move search - depth: {d}, ply: {d}\n", .{ searchDepth, nextPly });
            }

            score = -(try pvSearch(
                gameBoard,
                attackTable,
                searchDepth,
                nextPly,
                -beta,
                -alpha,
                true,
                info,
            ));
        } else {
            if (ply == 0) {
                std.debug.print("Reduced search - depth: {d}, ply: {d}, reduction: {d}\n", .{ searchDepth -| reduction, nextPly, reduction });
            }

            // Initial reduced search
            score = -(try pvSearch(
                gameBoard,
                attackTable,
                searchDepth -| reduction, // Use saturating subtraction
                nextPly,
                -(alpha + 1),
                -alpha,
                true,
                info,
            ));

            // Re-search at full depth if the reduced search was promising
            if (score > alpha and reduction > 0) {
                if (ply == 0) {
                    std.debug.print("Re-searching at full depth\n", .{});
                }

                score = -(try pvSearch(
                    gameBoard,
                    attackTable,
                    searchDepth,
                    nextPly,
                    -(alpha + 1),
                    -alpha,
                    true,
                    info,
                ));
            }

            // PVS full window search if needed
            if (score > alpha and score < beta) {
                if (ply == 0) {
                    std.debug.print("Full window search\n", .{});
                }

                score = -(try pvSearch(
                    gameBoard,
                    attackTable,
                    searchDepth,
                    nextPly,
                    -beta,
                    -alpha,
                    true,
                    info,
                ));
            }
        }

        gameBoard.* = savedBoard;

        if (ply == 0) {
            std.debug.print("Move score: {d}\n", .{score});
        }

        if (score >= beta) {
            if (move.moveType != .capture and move.moveType != .promotionCapture) {
                info.killers.update(move, ply);
                info.history.update(move.piece, @intCast(@intFromEnum(move.target)), newDepth);
            }
            if (ply == 0) std.debug.print("Beta cutoff\n", .{});
            return beta;
        }

        if (score > alpha) {
            alpha = score;
            bestMove = move;

            if (ply < MAX_PLY - 1) {
                info.pvTable[ply][ply] = move;
                var nextPlyPv: u8 = ply + 1;
                while (nextPlyPv < info.pvLength[ply + 1] and nextPlyPv < MAX_PLY) : (nextPlyPv += 1) {
                    info.pvTable[ply][nextPlyPv] = info.pvTable[ply + 1][nextPlyPv];
                }
                info.pvLength[ply] = info.pvLength[ply + 1];
            }

            if (ply == 0) {
                std.debug.print("New best move found\n", .{});
                info.bestMove = move;
            }
        }
    }

    return alpha;
}

fn printMove(move: movegen.Move) void {
    const sourceCoords = move.source.toCoordinates() catch return;
    const targetCoords = move.target.toCoordinates() catch return;
    std.debug.print("{c}{c}-{c}{c}", .{
        sourceCoords[0],
        sourceCoords[1],
        targetCoords[0],
        targetCoords[1],
    });
}
// Helper functions
fn isInCheck(gameBoard: *const bitboard.Board, attackTable: *const attacks.AttackTable) bool {
    const kingPiece = if (gameBoard.sideToMove == .white) bitboard.Piece.K else bitboard.Piece.k;
    const kingBoard = gameBoard.bitboard[@intFromEnum(kingPiece)];
    const kingSquare = @as(u6, @intCast(utils.getLSBindex(kingBoard)));

    return attacks.isSquareAttacked(kingSquare, gameBoard.sideToMove, gameBoard, attackTable);
}

fn isPawnEndgame(gameBoard: *const bitboard.Board) bool {
    const side = gameBoard.sideToMove;
    const pawns = if (side == .white)
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.P)]
    else
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.p)];

    return utils.countBits(pawns) > 0 and
        utils.countBits(gameBoard.occupancy[@intFromEnum(side)]) ==
        utils.countBits(pawns) + 1; // Only pawns + king
}

fn sortMoves(moves: []movegen.Move) void {
    // Simple insertion sort based on move scores
    // (stored in the unused isDoubleCheck/isDiscoveryCheck fields)
    var i: usize = 1;
    while (i < moves.len) : (i += 1) {
        const key = moves[i];
        var j: usize = i;
        while (j > 0 and getMoveScore(moves[j - 1]) < getMoveScore(key)) : (j -= 1) {
            moves[j] = moves[j - 1];
        }
        moves[j] = key;
    }
}

// Generate captures for quiescence search
fn generateCaptures(gameBoard: *bitboard.Board, attackTable: *const attacks.AttackTable, moves: *movegen.MoveList) void {
    const side = gameBoard.sideToMove;

    // Generate pawn captures and promotions
    var pawnBoard = if (side == .white)
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.P)]
    else
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.p)];

    const opponentPieces = gameBoard.occupancy[@intFromEnum(side.opposite())];

    while (pawnBoard != 0) {
        const source = utils.getLSBindex(pawnBoard);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        // Get pawn attacks
        const attack = attackTable.pawn[@intFromEnum(side)][sourceSquare] & opponentPieces;
        var attackBB = attack;

        while (attackBB != 0) {
            const target = utils.getLSBindex(attackBB);
            if (target < 0) break;
            const targetSquare = @as(u6, @intCast(target));

            // Check for promotion captures
            if ((side == .white and target < 8) or (side == .black and target >= 56)) {
                inline for ([_]movegen.PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotionPiece| {
                    moves.addMoveCallback(.{
                        .source = @enumFromInt(sourceSquare),
                        .target = @enumFromInt(targetSquare),
                        .piece = if (side == .white) .P else .p,
                        .promotionPiece = promotionPiece,
                        .moveType = .promotionCapture,
                    });
                }
            } else {
                // Normal captures
                moves.addMoveCallback(.{
                    .source = @enumFromInt(sourceSquare),
                    .target = @enumFromInt(targetSquare),
                    .piece = if (side == .white) .P else .p,
                    .moveType = .capture,
                });
            }

            attackBB &= attackBB - 1;
        }

        // Check en passant captures
        if (gameBoard.enpassant != .noSquare) {
            const epAttacks = attackTable.pawn[@intFromEnum(side)][sourceSquare] &
                (@as(u64, 1) << @intCast(@intFromEnum(gameBoard.enpassant)));
            if (epAttacks != 0) {
                moves.addMoveCallback(.{
                    .source = @enumFromInt(sourceSquare),
                    .target = gameBoard.enpassant,
                    .piece = if (side == .white) .P else .p,
                    .moveType = .enpassant,
                });
            }
        }

        pawnBoard &= pawnBoard - 1;
    }

    // Generate piece captures (knights, bishops, rooks, queens)
    // Knights
    var knightBoard = if (side == .white)
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.N)]
    else
        gameBoard.bitboard[@intFromEnum(bitboard.Piece.n)];

    while (knightBoard != 0) {
        const source = utils.getLSBindex(knightBoard);
        if (source < 0) break;
        const sourceSquare = @as(u6, @intCast(source));

        const attack = attackTable.knight[sourceSquare] & opponentPieces;
        var attackBB = attack;

        while (attackBB != 0) {
            const target = utils.getLSBindex(attackBB);
            if (target < 0) break;
            moves.addMoveCallback(.{
                .source = @enumFromInt(sourceSquare),
                .target = @enumFromInt(@as(u6, @intCast(target))),
                .piece = if (side == .white) .N else .n,
                .moveType = .capture,
            });
            attackBB &= attackBB - 1;
        }

        knightBoard &= knightBoard - 1;
    }

    // Sliding pieces (bishops, rooks, queens)
    inline for ([_]struct { piece: bitboard.Piece, is_bishop: bool }{
        .{ .piece = if (side == .white) .B else .b, .is_bishop = true },
        .{ .piece = if (side == .white) .R else .r, .is_bishop = false },
        .{ .piece = if (side == .white) .Q else .q, .is_bishop = false },
    }) |piece_info| {
        var pieceBoard = gameBoard.bitboard[@intFromEnum(piece_info.piece)];

        while (pieceBoard != 0) {
            const source = utils.getLSBindex(pieceBoard);
            if (source < 0) break;
            const sourceSquare = @as(u6, @intCast(source));

            const attack = if (piece_info.is_bishop)
                attacks.getBishopAttacks(sourceSquare, gameBoard.occupancy[2], attackTable)
            else
                attacks.getRookAttacks(sourceSquare, gameBoard.occupancy[2], attackTable);

            var attackBB = attack & opponentPieces;

            while (attackBB != 0) {
                const target = utils.getLSBindex(attackBB);
                if (target < 0) break;
                moves.addMoveCallback(.{
                    .source = @enumFromInt(sourceSquare),
                    .target = @enumFromInt(@as(u6, @intCast(target))),
                    .piece = piece_info.piece,
                    .moveType = .capture,
                });
                attackBB &= attackBB - 1;
            }

            pieceBoard &= pieceBoard - 1;
        }
    }
}

// Move scoring score extraction function
fn getMoveScore(move: movegen.Move) i32 {
    // Reconstruct score from the repurposed check fields
    const sign: i32 = if (move.isDoubleCheck) 1 else -1;
    const magnitude: i32 = if (move.isDiscoveryCheck) 1 else 0;
    return sign * (1000000 + magnitude);
}

// Generate all moves (used in main search)
pub fn generateAllMoves(gameBoard: *bitboard.Board, attackTable: *const attacks.AttackTable, moves: *movegen.MoveList) void {
    movegen.generatePawnMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback);
    movegen.generateKnightMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback);
    movegen.generateSlidingMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback, true); // bishops
    movegen.generateSlidingMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback, false); // rooks
    movegen.generateQueenMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback);
    movegen.generateKingMoves(gameBoard, attackTable, moves, movegen.MoveList.addMoveCallback);
}

// Comptime piece value calculation function
fn getPieceValue(piece_type: movegen.CapturedPiece) i32 {
    return switch (piece_type) {
        .none => 0,
        .P, .p => 100,
        .N, .n => 320,
        .B, .b => 330,
        .R, .r => 500,
        .Q, .q => 900,
        .K, .k => 20000,
    };
}

// Attacker value calculation function
fn getAttackerValue(piece: bitboard.Piece) i32 {
    return switch (piece) {
        .P, .p => 100,
        .N, .n => 320,
        .B, .b => 330,
        .R, .r => 500,
        .Q, .q => 900,
        .K, .k => 20000,
    };
}

// MVV-LVA scoring for captures
fn scoreCapture(move: movegen.Move) i32 {
    const victim_value = getPieceValue(move.capturedPiece);
    const attacker_value = getAttackerValue(move.piece);
    return victim_value * 100 - attacker_value;
}
