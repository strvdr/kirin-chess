const std = @import("std");
const board = @import("bitboard.zig");
const movegen = @import("movegen.zig");
const attacks = @import("attacks.zig");
const utils = @import("utils.zig");

/// Gets the current time in milliseconds using a monotonic clock
pub fn getTimeMs() i128 {
    return @divFloor(std.time.nanoTimestamp(), std.time.ns_per_ms);
}

/// A simple timer struct for measuring elapsed time
pub const Timer = struct {
    start_time: i128,

    pub fn start() Timer {
        return .{
            .start_time = getTimeMs(),
        };
    }

    pub fn elapsed(self: Timer) i128 {
        return getTimeMs() - self.start_time;
    }

    pub fn elapsedAndReset(self: *Timer) i128 {
        const current = getTimeMs();
        const elapse = current - self.start_time;
        self.start_time = current;
        return elapse;
    }
};

pub const PerftResult = struct {
    nodes: u64 = 0,
    captures: u64 = 0,
    en_passants: u64 = 0,
    castles: u64 = 0,
    promotions: u64 = 0,
    checks: u64 = 0,
};

pub const Perft = struct {
    board: *board.Board,
    attack_table: *attacks.AttackTable,

    pub fn init(b: *board.Board, atk: *attacks.AttackTable) Perft {
        return .{
            .board = b,
            .attack_table = atk,
        };
    }
    pub fn debugMoveGeneration(self: *Perft) void {
        var all_moves = movegen.MoveList.init();

        // Generate all moves at once for total count
        self.generateAllMoves(&all_moves);

        std.debug.print("\nDebug Move Generation for position:\n", .{});
        utils.printBoard(self.board);

        std.debug.print("\nTotal moves possible: {d}\n", .{all_moves.count});
        std.debug.print("\nMoves by piece type:\n", .{});

        // Now generate and print moves by piece type
        var moves = movegen.MoveList.init();

        moves.clear();
        movegen.generatePawnMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateKnightMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateSlidingMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback, true);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateSlidingMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback, false);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateQueenMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateKingMoves(self.board, self.attack_table, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);
    }

    /// Counts all possible moves at a given depth
    pub fn perftCount(self: *Perft, depth: u32) u64 {
        if (depth == 0) return 1;

        var nodes: u64 = 0;
        var moves = movegen.MoveList.init();

        // Generate all moves for current position
        self.generateAllMoves(&moves);

        // Recurse through each move
        for (moves.getMoves()) |move| {
            // Make move on a copy of the board
            var board_copy = self.board.*;
            // Try to make the move, skip if it leaves/puts king in check
            if (board_copy.makeMove(move, self.attack_table)) |_| {
                nodes += self.perftCount(depth - 1);
            } else |_| {
                // Move was illegal (probably leaves king in check), skip it
                continue;
            }
        }

        return nodes;
    }
    // Performs a detailed perft analysis and prints move breakdowns
    pub fn perftDivide(self: *Perft, depth: u32) !PerftResult {
        var total = PerftResult{};
        var moves = movegen.MoveList.init();

        // Generate all moves
        self.generateAllMoves(&moves);

        std.debug.print("\nPerft Divide at depth {d}:\n", .{depth});
        std.debug.print("Total moves at root: {d}\n\n", .{moves.count});

        // Process each move at root level
        for (moves.getMoves()) |move| {
            var board_copy = self.board.*;
            board_copy.makeMoveUnchecked(move);

            // Count nodes after this move
            const nodes = if (depth > 1)
                try self.perftCountDetailed(depth - 1)
            else
                PerftResult{ .nodes = 1 };

            // Print move details
            const fromCoords = move.from.toCoordinates() catch unreachable;
            const toCoords = move.to.toCoordinates() catch unreachable;
            std.debug.print("{c}{c}{c}{c}: {d} nodes", .{
                fromCoords[0], fromCoords[1],
                toCoords[0],   toCoords[1],
                nodes.nodes,
            });

            // Add special move info
            switch (move.moveType) {
                .capture, .promotionCapture => {
                    std.debug.print(" (capture)", .{});
                    total.captures += 1;
                },
                .promotion => {
                    std.debug.print(" (promotion)", .{});
                    total.promotions += 1;
                },
                .castle => {
                    std.debug.print(" (castle)", .{});
                    total.castles += 1;
                },
                .enpassant => {
                    std.debug.print(" (en passant)", .{});
                    total.en_passants += 1;
                },
                else => {},
            }
            std.debug.print("\n", .{});

            // Accumulate totals
            total.nodes += nodes.nodes;
            total.captures += nodes.captures;
            total.en_passants += nodes.en_passants;
            total.castles += nodes.castles;
            total.promotions += nodes.promotions;
            total.checks += nodes.checks;
        }

        return total;
    }

    /// Helper function for perftDivide that tracks detailed statistics
    fn perftCountDetailed(self: *Perft, depth: u32) !PerftResult {
        if (depth == 0) return PerftResult{ .nodes = 1 };

        var result = PerftResult{};
        var moves = movegen.MoveList.init();

        // Generate all moves
        self.generateAllMoves(&moves);

        // Process each move
        for (moves.getMoves()) |move| {
            var board_copy = self.board.*;
            board_copy.makeMoveUnchecked(move);

            // Count nodes for this move
            const nodes = if (depth > 1)
                try self.perftCountDetailed(depth - 1)
            else
                PerftResult{ .nodes = 1 };

            // Accumulate statistics
            result.nodes += nodes.nodes;
            result.captures += nodes.captures;
            result.en_passants += nodes.en_passants;
            result.castles += nodes.castles;
            result.promotions += nodes.promotions;
            result.checks += nodes.checks;

            // Add special move counts
            switch (move.moveType) {
                .capture, .promotionCapture => result.captures += 1,
                .promotion => result.promotions += 1,
                .castle => result.castles += 1,
                .enpassant => result.en_passants += 1,
                else => {},
            }
        }

        return result;
    }

    /// Generates all legal moves for the current position
    fn generateAllMoves(self: *Perft, moves: *movegen.MoveList) void {
        // Generate moves for all piece types
        movegen.generatePawnMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback);
        movegen.generateKnightMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback);
        movegen.generateSlidingMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback, true); // bishops
        movegen.generateSlidingMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback, false); // rooks
        movegen.generateQueenMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback);
        movegen.generateKingMoves(self.board, self.attack_table, moves, movegen.MoveList.addMoveCallback);
    }
};

fn printMovesByPiece(moves: *movegen.MoveList) void {
    for (moves.getMoves()) |move| {
        const fromCoords = move.from.toCoordinates() catch unreachable;
        const toCoords = move.to.toCoordinates() catch unreachable;

        const pieceType = switch (move.piece) {
            .P, .p => "Pawn",
            .N, .n => "Knight",
            .B, .b => "Bishop",
            .R, .r => "Rook",
            .Q, .q => "Queen",
            .K, .k => "King",
        };

        const moveType = switch (move.moveType) {
            .quiet => "quiet",
            .capture => "capture",
            .promotion => "promotion",
            .promotionCapture => "promotion capture",
            .doublePush => "double push",
            .enpassant => "en passant",
            .castle => "castle",
        };

        std.debug.print("{s}: {c}{c}-{c}{c} ({s})\n", .{
            pieceType,
            fromCoords[0],
            fromCoords[1],
            toCoords[0],
            toCoords[1],
            moveType,
        });
    }
}
