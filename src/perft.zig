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
    discoveryChecks: u64 = 0,
    doubleChecks: u64 = 0,
    checkmates: u64 = 0,
    quiet: u64 = 0,
    currentMove: ?movegen.Move = null,
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

    fn perftCountInternal(self: *Perft, depth: u32, targetDepth: u32, stats: *PerftResult) u64 {
        if (depth == 0) {
            // At a leaf node, classify the current move
            if (stats.currentMove) |move| {
                if (move.isCheck) {
                    stats.checks += 1;

                    // Track discovery and double checks
                    if (move.isDiscoveryCheck) {
                        stats.discoveryChecks += 1;
                        stats.checks -= 1;
                    }
                    if (move.isDoubleCheck) {
                        stats.doubleChecks += 1;
                        stats.checks -= 1;
                    }

                    // Check for checkmate by trying to generate moves for the opponent
                    var moves = movegen.MoveList.init();
                    const savedBoard = self.board.*;

                    // Generate all possible moves for opponent
                    self.generateAllMoves(&moves);

                    // If no legal moves exist and king is in check, it's checkmate
                    if (moves.count == 0) {
                        stats.checkmates += 1;
                    }

                    // Restore the board
                    self.board.* = savedBoard;
                }

                switch (move.moveType) {
                    .capture => stats.captures += 1,
                    .promotionCapture => {
                        stats.promotions += 1;
                        stats.captures += 1;
                    },
                    .castle => stats.castles += 1,
                    .promotion => stats.promotions += 1,
                    .enpassant => {
                        stats.en_passants += 1;
                        stats.captures += 1;
                    },
                    .quiet, .doublePush => stats.quiet += 1,
                }
            }
            return 1;
        }

        var nodes: u64 = 0;
        var moves = movegen.MoveList.init();
        self.generateAllMoves(&moves);

        for (moves.getMoves()) |move| {
            const saved_board = self.board.*;
            const saved_move = stats.currentMove; // Save current move

            stats.currentMove = move; // Set current move for this branch
            self.board.makeMove(move) catch unreachable;

            const subnodes = self.perftCountInternal(depth - 1, targetDepth, stats);
            nodes += subnodes;

            stats.currentMove = saved_move; // Restore previous move
            self.board.* = saved_board;
        }

        return nodes;
    }

    pub fn perftCount(self: *Perft, depth: u32) u64 {
        var stats = PerftResult{};
        const nodes = self.perftCountInternal(depth, depth, &stats);

        // Print stats at the end
        std.debug.print("\nTotal for depth {d}:\n", .{depth});
        std.debug.print("Captures: {d}\n", .{stats.captures});
        std.debug.print("En passants: {d}\n", .{stats.en_passants});
        std.debug.print("Castles: {d}\n", .{stats.castles});
        std.debug.print("Promotions: {d}\n", .{stats.promotions});
        std.debug.print("Checks: {d}\n", .{stats.checks});
        std.debug.print("Discovery checks: {d}\n", .{stats.discoveryChecks});
        std.debug.print("Double checks: {d}\n", .{stats.doubleChecks});
        std.debug.print("Checkmates: {d}\n", .{stats.checkmates});
        std.debug.print("Quiet moves: {d}\n", .{stats.quiet});
        std.debug.print("Total nodes: {d}\n", .{nodes});

        return nodes;
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
