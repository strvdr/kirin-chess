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
//

const std = @import("std");
const board = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");
const utils = @import("utils.zig");

const MoveCollector = struct {
    moves: [256]movegen.Move = undefined,
    count: usize = 0,

    pub fn addMove(self: *@This(), move: movegen.Move) void {
        if (self.count < self.moves.len) {
            self.moves[self.count] = move;
            self.count += 1;
        }
    }

    pub fn clear(self: *@This()) void {
        self.count = 0;
    }
};

fn printMoveInfo(comptime prefix: []const u8, moves: []const movegen.Move) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n{s} ({d} moves found):\n", .{ prefix, moves.len });
    for (moves) |move| {
        move.print();
    }
    try stdout.print("\n", .{});
}

fn testPosition(b: *board.Board, attack_table: *attacks.AttackTable, fen: []const u8, position_name: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // Initialize position
    try utils.parseFEN(b, fen);
    try stdout.print("\nTesting position: {s}\n", .{position_name});
    utils.printBoard(b);

    // Create move collector and generate moves
    var collector = MoveCollector{};
    const addMoveFn = struct {
        fn add(ctx: *MoveCollector, move: movegen.Move) void {
            ctx.addMove(move);
        }
    }.add;

    // Generate pawn moves for the current side
    movegen.generatePawnMoves(b, attack_table, &collector, addMoveFn);
    try printMoveInfo("Legal pawn moves", collector.moves[0..collector.count]);
}

pub fn main() !void {
    // Initialize board and attack tables
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Test different positions
    try testPosition(&b, &attack_table, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "Initial Position");

    try testPosition(&b, &attack_table, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/Pp2P3/2N2Q1p/1PPBBPPP/R3K2R b KQkq - 0 1", "Complex Middlegame Position");

    try testPosition(&b, &attack_table, "8/P7/8/8/8/8/p7/8 w - - 0 1", "Pawn Promotion Test Position");

    try testPosition(&b, &attack_table, "8/8/8/pP6/8/8/8/8 w - a6 0 1", "En Passant Test Position");
}

test "pawn move generation" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Structure to count moves
    const Context = struct {
        count: usize = 0,

        fn countMove(self: *@This(), _: movegen.Move) void {
            self.count += 1;
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    // Test initial position white pawn moves
    try utils.parseFEN(&b, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    movegen.generatePawnMoves(&b, &attack_table, &context, countMoveFn);

    // In the initial position, each pawn should have 2 possible moves (single and double push)
    try std.testing.expectEqual(@as(usize, 8), context.count);
}

test "pawn promotion generation" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    const Context = struct {
        count: usize = 0,

        fn countMove(self: *@This(), _: movegen.Move) void {
            self.count += 1;
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    // Test a position where a pawn can promote
    try utils.parseFEN(&b, "8/P7/8/8/8/8/p7/8 w - - 0 1");
    movegen.generatePawnMoves(&b, &attack_table, &context, countMoveFn);

    // Each pawn promotion generates 4 moves (queen, rook, bishop, knight)
    try std.testing.expectEqual(@as(usize, 4), context.count);
}

test "en passant generation" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    const Context = struct {
        count: usize = 0,

        fn countMove(self: *@This(), _: movegen.Move) void {
            self.count += 1;
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    // Test a position where en passant is possible
    try utils.parseFEN(&b, "8/8/8/pP6/8/8/8/8 w - a6 0 1");
    movegen.generatePawnMoves(&b, &attack_table, &context, countMoveFn);

    // There should be exactly 1 en passant move
    try std.testing.expectEqual(@as(usize, 1), context.count);
}

test "blocked pawn moves" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    const Context = struct {
        count: usize = 0,

        fn countMove(self: *@This(), _: movegen.Move) void {
            self.count += 1;
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    // Test a position where pawns are blocked by pieces
    try utils.parseFEN(&b, "8/8/8/8/pppppppp/PPPPPPPP/8/8 w - - 0 1");
    movegen.generatePawnMoves(&b, &attack_table, &context, countMoveFn);

    // No pawn moves should be generated as all pawns are blocked
    try std.testing.expectEqual(@as(usize, 12), context.count);
}
