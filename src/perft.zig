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
    startTime: i128,

    pub fn start() Timer {
        return .{
            .startTime = getTimeMs(),
        };
    }

    pub fn elapsed(self: Timer) i128 {
        return getTimeMs() - self.startTime;
    }

    pub fn elapsedAndReset(self: *Timer) i128 {
        const current = getTimeMs();
        const elapse = current - self.startTime;
        self.startTime = current;
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
    attackTable: *attacks.AttackTable,

    pub fn init(b: *board.Board, atk: *attacks.AttackTable) Perft {
        return .{
            .board = b,
            .attackTable = atk,
        };
    }

    pub fn debugMoveGeneration(self: *Perft) void {
        var allMoves = movegen.MoveList.init();

        // Generate all moves at once for total count
        self.generateAllMoves(&allMoves);

        std.debug.print("\nDebug Move Generation for position:\n", .{});
        utils.printBoard(self.board);

        std.debug.print("\nTotal moves possible: {d}\n", .{allMoves.count});
        std.debug.print("\nMoves by piece type:\n", .{});

        // Now generate and print moves by piece type
        var moves = movegen.MoveList.init();

        moves.clear();
        movegen.generatePawnMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateKnightMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateSlidingMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback, true);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateSlidingMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback, false);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateQueenMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);

        moves.clear();
        movegen.generateKingMoves(self.board, self.attackTable, &moves, movegen.MoveList.addMoveCallback);
        printMovesByPiece(&moves);
    }

    fn perftCountInternal(self: *Perft, depth: u32, targetDepth: u32) u64 {
        if (depth == 0) return 1;

        var nodes: u64 = 0;
        var moves = movegen.MoveList.init();
        var stats = PerftResult{};

        self.generateAllMoves(&moves);

        for (moves.getMoves()) |move| {
            const saved_board = self.board.*;

            var is_legal: u1 = 1;
            self.board.makeMove(move) catch {
                self.board.* = saved_board;
                is_legal = 0;
            };

            if (is_legal == 1) {
                // Collect stats when we're one move away from target depth
                if (depth == targetDepth - 1) {
                    var reply_moves = movegen.MoveList.init();
                    self.generateAllMoves(&reply_moves);

                    for (reply_moves.getMoves()) |reply| {
                        switch (reply.moveType) {
                            .capture => stats.captures += 1,
                            .castle => stats.castles += 1,
                            .promotion, .promotionCapture => stats.promotions += 1,
                            .enpassant => stats.en_passants += 1,
                            else => {},
                        }
                    }

                    const fromCoords = move.from.toCoordinates() catch continue;
                    const toCoords = move.to.toCoordinates() catch continue;
                    std.debug.print("Move {c}{c}-{c}{c} ({s} {s}) generated {d} replies\n", .{
                        fromCoords[0],        fromCoords[1],
                        toCoords[0],          toCoords[1],
                        @tagName(move.piece), @tagName(move.moveType),
                        reply_moves.count,
                    });
                }

                const subnodes = self.perftCountInternal(depth - 1, targetDepth);
                nodes += subnodes;
            }
            self.board.* = saved_board;
        }

        if (depth == targetDepth - 1) {
            std.debug.print("\nTotal for depth {d}:\n", .{targetDepth});
            std.debug.print("Captures: {d}\n", .{stats.captures});
            std.debug.print("En passants: {d}\n", .{stats.en_passants});
            std.debug.print("Castles: {d}\n", .{stats.castles});
            std.debug.print("Promotions: {d}\n", .{stats.promotions});
            std.debug.print("Checks: {d}\n", .{stats.checks});
            std.debug.print("Total nodes: {d}\n", .{nodes});
        }

        return nodes;
    }

    pub fn perftCount(self: *Perft, depth: u32) u64 {
        return self.perftCountInternal(depth, depth + 1);
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
            try board_copy.makeMove(move, self.attackTable);

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

            try board_copy.makeMove(move, self.attackTable);

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
        movegen.generatePawnMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback);
        movegen.generateKnightMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback);
        movegen.generateSlidingMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback, true); // bishops
        movegen.generateSlidingMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback, false); // rooks
        movegen.generateQueenMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback);
        movegen.generateKingMoves(self.board, self.attackTable, moves, movegen.MoveList.addMoveCallback);
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
