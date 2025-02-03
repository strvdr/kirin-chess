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
const movegen = @import("movegen.zig");
const attacks = @import("attacks.zig");
const evaluation = @import("evaluation.zig");
const utils = @import("utils.zig");
const transposition = @import("transposition.zig");

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
const HISTORY_PRUNING_THRESHOLD = -4000;

pub const SearchError = error{
    SearchStopped,
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
    depth: i8 = 0,
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
        // Opening specific scoring
        else if (ply < 10) { // Only in first 5 moves
            // Bonus for central pawn moves
            if (move.piece == .P or move.piece == .p) {
                const target_file = @mod(@intFromEnum(move.target), 8);
                const target_rank = @divFloor(@intFromEnum(move.target), 8);
                if (target_file >= 2 and target_file <= 5) { // Central files
                    score += 50000;
                    if (target_rank >= 2 and target_rank <= 5) { // Central ranks
                        score += 25000;
                    }
                }
            }
            // Penalty for early knight moves to edges
            if (move.piece == .N or move.piece == .n) {
                const target_file = @mod(@intFromEnum(move.target), 8);
                if (target_file == 0 or target_file == 7) {
                    score -= 75000;
                }
            }
        }
        // Finally history score
        score += info.history.get(move.piece, @intCast(@intFromEnum(move.target)));

        // Store score in the unused fields of the move
        move.isDoubleCheck = (score > 0);
        move.isDiscoveryCheck = (score < 0);
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
    if (info.nodes & 1023 == 0 and info.shouldStop) {
        return 0;
    }

    // Stand pat with evaluation
    const standPat = evaluation.evaluate(gameBoard);

    // Beta cutoff
    if (standPat >= beta) {
        return beta;
    }

    // Delta pruning
    const bigDelta = 900; // Value of a queen
    if (standPat + bigDelta < alpha_) {
        return alpha_;
    }

    var alpha = alpha_;
    if (standPat > alpha) {
        alpha = standPat;
    }

    // Generate only captures
    var moveList = movegen.MoveList.init();
    generateCaptures(gameBoard, attackTable, &moveList);

    // Score and sort captures
    scoreMoves(info, moveList.getMovesMut(), 0, null);
    sortMoves(moveList.getMovesMut());

    const savedBoard = gameBoard.*;

    // Loop through captures
    for (moveList.getMoves()) |move| {
        // Futility pruning for captures
        if (@TypeOf(move.capturedPiece) == movegen.CapturedPiece) {
            const captureValue = getPieceValue(move.capturedPiece);
            if (standPat + captureValue + 200 < alpha) {
                continue;
            }
        }

        // Make move
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
    tt: *transposition.TranspositionTable,
    depth: i8,
    ply: u8,
    alpha_: i32,
    beta: i32,
    info: *SearchInfo,
    limits: *const SearchLimits,
) !i32 {
    if ((info.nodes & 1023) == 0 and limits.shouldStop(info)) {
        return error.SearchTimeout;
    }

    info.nodes += 1;

    // Base cases
    if (depth <= 0) {
        return quiescence(gameBoard, attackTable, alpha_, beta, info);
    }

    if (ply >= MAX_PLY - 1) {
        return evaluation.evaluate(gameBoard);
    }

    const inCheck = isInCheck(gameBoard, attackTable);
    const isPv = beta - alpha_ > 1;
    var alpha = alpha_;

    // Transposition table lookup
    const posKey = generatePositionKey(gameBoard);
    if (ply > 0) { // Skip at root
        const ttEntry = tt.probe(posKey, ply, alpha, beta, depth);
        if (ttEntry) |entry| {
            if (@as(i8, entry.depth) >= depth and !isPv) {
                const ttScore = entry.score;
                switch (entry.entryType) {
                    .exact => return ttScore,
                    .alpha => if (ttScore <= alpha) return alpha,
                    .beta => if (ttScore >= beta) return beta,
                }
            }
        }
    }

    // Null move pruning
    if (!inCheck and depth >= 3 and !isPv and ply > 0) {
        const savedBoard = gameBoard.*;
        gameBoard.sideToMove = gameBoard.sideToMove.opposite();
        gameBoard.enpassant = .noSquare;

        const score = -(try pvSearch(gameBoard, attackTable, tt, depth - 3, // More aggressive reduction
            ply + 1, -beta, -beta + 1, info, limits));

        gameBoard.* = savedBoard;

        if (score >= beta) {
            return beta;
        }
    }

    // Initialize move generation
    var moveList = movegen.MoveList.init();
    generateAllMoves(gameBoard, attackTable, &moveList);

    if (moveList.count == 0) {
        if (inCheck) {
            return -MATE_SCORE + @as(i32, ply);
        }
        return 0;
    }

    var bestMove: ?movegen.Move = null;
    var moveCount: i8 = 0;
    var hashFlag = transposition.TTEntryType.alpha;

    // Get TT move if available
    const ttEntry = tt.probe(posKey, ply, alpha, beta, depth);
    const ttMove = if (ttEntry) |entry| entry.bestMove else null;

    // Score and sort moves
    scoreMoves(info, moveList.getMovesMut(), ply, ttMove);
    sortMoves(moveList.getMovesMut());

    const savedBoard = gameBoard.*;

    // Main move loop
    for (moveList.getMovesMut()) |move| {
        moveCount += 1;

        // History pruning
        if (depth >= 3 and !isPv and !inCheck and
            move.moveType != .capture and move.moveType != .promotionCapture and
            alpha > -MATE_THRESHOLD and moveCount > 4)
        {
            const history_score = info.history.get(move.piece, @intCast(@intFromEnum(move.target)));
            if (history_score < HISTORY_PRUNING_THRESHOLD) {
                continue;
            }
        }

        gameBoard.makeMove(move) catch {
            gameBoard.* = savedBoard;
            continue;
        };

        var score: i32 = undefined;
        const newDepth = depth - 1;

        // Late Move Reduction
        if (moveCount >= 4 and depth >= 3 and !inCheck and
            move.moveType != .capture and move.moveType != .promotionCapture)
        {
            const reduction: i8 = if (moveCount >= 6)
                @min(@divFloor(depth, 3), 3 + @as(i8, @intFromBool(depth >= 16)) + @divFloor(moveCount, 8))
            else
                1;

            score = -(try pvSearch(gameBoard, attackTable, tt, newDepth - reduction, ply + 1, -alpha - 1, -alpha, info, limits));

            if (score > alpha) {
                // Research at full depth
                score = -(try pvSearch(gameBoard, attackTable, tt, newDepth, ply + 1, -beta, -alpha, info, limits));
            }
        } else if (moveCount == 1) {
            // First move - full window search
            score = -(try pvSearch(gameBoard, attackTable, tt, newDepth, ply + 1, -beta, -alpha, info, limits));
        } else {
            // Try null window search first
            score = -(try pvSearch(gameBoard, attackTable, tt, newDepth, ply + 1, -alpha - 1, -alpha, info, limits));

            if (score > alpha and score < beta) {
                // Research with full window
                score = -(try pvSearch(gameBoard, attackTable, tt, newDepth, ply + 1, -beta, -alpha, info, limits));
            }
        }

        gameBoard.* = savedBoard;

        if (score > alpha) {
            hashFlag = .exact;
            bestMove = move;
            if (ply == 0) { // Add this line: update info.bestMove at root
                info.bestMove = move;
            }
            alpha = score;

            // Update history
            if (move.moveType != .capture and move.moveType != .promotionCapture) {
                info.history.update(move.piece, @intCast(@intFromEnum(move.target)), @intCast(depth));
            }

            if (score >= beta) {
                // Beta cutoff - store killer moves
                if (move.moveType != .capture and move.moveType != .promotionCapture) {
                    info.killers.update(move, ply);
                }

                tt.store(posKey, @intCast(depth), beta, .beta, bestMove, ply);
                return beta;
            }
        }
    }

    // Store position in transposition table
    tt.store(posKey, @intCast(depth), alpha, hashFlag, bestMove, ply);
    return alpha;
}

fn generatePositionKey(gameBoard: *const bitboard.Board) u64 {
    var key: u64 = 0;

    // Hash piece positions
    inline for (gameBoard.bitboard, 0..) |board, piece_idx| {
        var pieces = board;
        while (pieces != 0) {
            const square = utils.getLSBindex(pieces);
            if (square >= 0) {
                key ^= transposition.ZobristKeys.pieces[piece_idx][@intCast(square)];
            }
            pieces &= pieces - 1;
        }
    }

    // Hash side to move
    if (gameBoard.sideToMove == .black) {
        key ^= transposition.ZobristKeys.side;
    }

    // Hash castling rights
    if (gameBoard.castling.whiteKingside) key ^= transposition.ZobristKeys.castling[0];
    if (gameBoard.castling.whiteQueenside) key ^= transposition.ZobristKeys.castling[1];
    if (gameBoard.castling.blackKingside) key ^= transposition.ZobristKeys.castling[2];
    if (gameBoard.castling.blackQueenside) key ^= transposition.ZobristKeys.castling[3];

    // Hash en passant
    if (gameBoard.enpassant != .noSquare) {
        key ^= transposition.ZobristKeys.enpassant[@intFromEnum(gameBoard.enpassant)];
    }

    return key;
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

pub const SearchLimits = struct {
    depth: i8 = 64,
    movetime: ?u64 = null,
    nodes: ?u64 = null,
    startTime: i128 = 0,
    infinite: bool = false, // Add this field

    pub fn shouldStop(self: *const SearchLimits, info: *SearchInfo) bool {
        // Don't stop if we're in an infinite or depth-based search
        if (self.infinite) {
            return info.shouldStop; // Only stop on explicit stop command
        }

        // Check node limit
        if (self.nodes) |maxNodes| {
            if (info.nodes >= maxNodes) {
                return true;
            }
        }

        // Check time limit
        if (self.movetime) |maxTime| {
            const elapsed = std.time.milliTimestamp() - self.startTime;
            if (elapsed >= maxTime) {
                return true;
            }
        }

        return info.shouldStop;
    }
};

pub const SearchResult = struct {
    bestMove: ?movegen.Move = null,
    score: i32 = 0,
    depth: i8 = 0,
    nodes: u64 = 0,
};

pub fn startSearch(
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
    transpositionTable: *transposition.TranspositionTable,
    limits: SearchLimits,
) !SearchResult {
    var info = SearchInfo{};
    var result = SearchResult{};
    var limits_with_time = limits;
    limits_with_time.startTime = std.time.milliTimestamp();

    // Generate moves at root and ensure we have at least one move
    var moveList = movegen.MoveList.init();
    generateAllMoves(gameBoard, attackTable, &moveList);

    if (moveList.count > 0) {
        // Store first legal move as fallback
        for (moveList.getMoves()) |move| {
            if (movegen.isMoveLegal(gameBoard, move, attackTable)) {
                result.bestMove = move;
                break;
            }
        }
    }

    // Clear old PV
    @memset(&info.pvLength, 0);
    @memset(&info.pvTable, undefined);

    // Iterative deepening
    var iterationDepth: i8 = 1;
    while (iterationDepth <= limits.depth) : (iterationDepth += 1) {
        const score = pvSearch(
            gameBoard,
            attackTable,
            transpositionTable,
            iterationDepth,
            0,
            -INFINITY,
            INFINITY,
            &info,
            &limits_with_time,
        ) catch |err| {
            std.debug.print("timeout, {}\n", .{err});
            // If we error out (including timeout), return best move found so far
            break;
        };

        // Only update result if we completed the iteration
        if (!limits_with_time.shouldStop(&info)) {
            result.bestMove = info.bestMove;
            result.score = score;
            result.depth = iterationDepth;
            result.nodes = info.nodes;

            // Print UCI info
            try printSearchInfo(&info, score, iterationDepth);
        } else {
            break;
        }
    }

    return result;
}

fn printSearchInfo(info: *const SearchInfo, score: i32, depth: i8) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("info depth {d} score ", .{depth});

    // Print score (handle mate scores specially)
    if (score > MATE_THRESHOLD) {
        const movesToMate = @divFloor(MATE_SCORE - score + 1, 2);
        try stdout.print("mate {d} ", .{movesToMate});
    } else if (score < -MATE_THRESHOLD) {
        const movesToMate = @divFloor(MATE_SCORE + score, 2);
        try stdout.print("mate -{d} ", .{movesToMate});
    } else {
        try stdout.print("cp {d} ", .{score});
    }

    // Print nodes and principal variation
    try stdout.print("nodes {d}", .{info.nodes});

    // Print PV line if available
    if (info.pvLength[0] > 0) {
        try stdout.print(" pv", .{});
        var i: usize = 0;
        while (i < info.pvLength[0] and i < MAX_PLY) : (i += 1) {
            const move = info.pvTable[0][i];
            const sourceCoords = try move.source.toCoordinates();
            const targetCoords = try move.target.toCoordinates();

            try stdout.print(" {c}{c}{c}{c}", .{
                sourceCoords[0],
                sourceCoords[1],
                targetCoords[0],
                targetCoords[1],
            });

            // Add promotion piece if applicable
            if (move.moveType == .promotion or move.moveType == .promotionCapture) {
                switch (move.promotionPiece) {
                    .queen => try stdout.print("q", .{}),
                    .rook => try stdout.print("r", .{}),
                    .bishop => try stdout.print("b", .{}),
                    .knight => try stdout.print("n", .{}),
                    .none => {},
                }
            }
        }
    }

    try stdout.print("\n", .{});
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
