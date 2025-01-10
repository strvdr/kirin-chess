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

fn testPosition(b: *board.Board, attackTable: *attacks.AttackTable, fen: []const u8, positionName: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // Initialize position
    try utils.parseFEN(b, fen);
    try stdout.print("\nTesting position: {s}\n", .{positionName});
    utils.printBoard(b);

    // Create move collector and generate moves
    var collector = MoveCollector{};
    const addMoveFn = struct {
        fn add(ctx: *MoveCollector, move: movegen.Move) void {
            ctx.addMove(move);
        }
    }.add;

    // Generate pawn moves for the current side
    movegen.generatePawnMoves(b, attackTable, &collector, addMoveFn);
    try printMoveInfo("Legal pawn moves", collector.moves[0..collector.count]);
}

pub fn main() !void {
    // Initialize board and attack tables
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test rook moves
    try utils.parseFEN(&b, "8/8/3p4/8/2R1p3/8/8/8 w - - 0 1");
    std.debug.print("\nTesting rook moves:\n", .{});
    utils.printBoard(&b);

    const rook_square = 26; // c4
    std.debug.print("\nRook attack mask (ignoring occupancy):\n", .{});
    utils.printBitboard(attackTable.rookMasks[rook_square]);

    std.debug.print("\nOccupancy bitboard:\n", .{});
    utils.printBitboard(b.occupancy[2]);

    const rookAttacks = attacks.getRookAttacks(rook_square, b.occupancy[2], &attackTable);
    std.debug.print("\nRook attacks with current occupancy:\n", .{});
    utils.printBitboard(rookAttacks);

    const friendlyPieces = b.occupancy[@intFromEnum(b.sideToMove)];
    std.debug.print("\nFriendly pieces bitboard:\n", .{});
    utils.printBitboard(friendlyPieces);

    const opponentPieces = b.occupancy[@intFromEnum(b.sideToMove.opposite())];
    std.debug.print("\nOpponent pieces bitboard:\n", .{});
    utils.printBitboard(opponentPieces);

    const legalRookMoves = rookAttacks & ~friendlyPieces;
    std.debug.print("\nLegal rook moves after removing friendly pieces:\n", .{});
    utils.printBitboard(legalRookMoves);

    // Test bishop moves
    try utils.parseFEN(&b, "8/8/5p2/4B3/2p5/8/8/8 w - - 0 1");
    std.debug.print("\nTesting bishop moves:\n", .{});
    utils.printBoard(&b);

    const bishopSquare = 36; // e5
    std.debug.print("\nBishop attack mask (ignoring occupancy):\n", .{});
    utils.printBitboard(attackTable.bishopMasks[bishopSquare]);

    std.debug.print("\nOccupancy bitboard:\n", .{});
    utils.printBitboard(b.occupancy[2]);

    const bishopAttacks = attacks.getBishopAttacks(bishopSquare, b.occupancy[2], &attackTable);
    std.debug.print("\nBishop attacks with current occupancy:\n", .{});
    utils.printBitboard(bishopAttacks);

    const friendlyPiecesBishop = b.occupancy[@intFromEnum(b.sideToMove)];
    std.debug.print("\nFriendly pieces bitboard:\n", .{});
    utils.printBitboard(friendlyPiecesBishop);

    const opponentPiecesBishop = b.occupancy[@intFromEnum(b.sideToMove.opposite())];
    std.debug.print("\nOpponent pieces bitboard:\n", .{});
    utils.printBitboard(opponentPiecesBishop);

    const legalBishopMoves = bishopAttacks & ~friendlyPiecesBishop;
    std.debug.print("\nLegal bishop moves after removing friendly pieces:\n", .{});
    utils.printBitboard(legalBishopMoves);

    // Print final move counts
    var collector = MoveCollector{};
    const addMoveFn = struct {
        fn add(ctx: *MoveCollector, move: movegen.Move) void {
            ctx.addMove(move);
        }
    }.add;

    collector.clear();
    movegen.generateSlidingMoves(&b, &attackTable, &collector, addMoveFn, true);
    try printMoveInfo("Legal bishop moves", collector.moves[0..collector.count]);

    try utils.parseFEN(&b, "8/8/3p4/8/2R1p3/8/8/8 w - - 0 1");
    collector.clear();
    movegen.generateSlidingMoves(&b, &attackTable, &collector, addMoveFn, false);
    try printMoveInfo("Legal rook moves", collector.moves[0..collector.count]);
}

test "pawn move generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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
    movegen.generatePawnMoves(&b, &attackTable, &context, countMoveFn);

    // In the initial position, each pawn should have 2 possible moves (single and double push)
    try std.testing.expectEqual(@as(usize, 8), context.count);
}

test "pawn promotion generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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
    movegen.generatePawnMoves(&b, &attackTable, &context, countMoveFn);

    // Each pawn promotion generates 4 moves (queen, rook, bishop, knight)
    try std.testing.expectEqual(@as(usize, 4), context.count);
}

test "en passant generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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
    movegen.generatePawnMoves(&b, &attackTable, &context, countMoveFn);

    // There should be exactly 1 en passant move
    try std.testing.expectEqual(@as(usize, 1), context.count);
}

test "blocked pawn moves" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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
    movegen.generatePawnMoves(&b, &attackTable, &context, countMoveFn);

    // No pawn moves should be generated as all pawns are blocked
    try std.testing.expectEqual(@as(usize, 12), context.count);
}

test "knight move generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    // Test initial position knight moves
    try utils.parseFEN(&b, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    movegen.generateKnightMoves(&b, &attackTable, &context, countMoveFn);
    // In the initial position, each knight should have 2 possible moves
    try std.testing.expectEqual(@as(usize, 4), context.count);
}

test "king move generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    // Test initial position - king should have no legal moves
    try utils.parseFEN(&b, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    movegen.generateKingMoves(&b, &attackTable, &context, countMoveFn);
    try std.testing.expectEqual(@as(usize, 0), context.count);

    // Reset context
    context.count = 0;

    // Test king in the middle of an empty board - should have 8 moves
    try utils.parseFEN(&b, "8/8/8/8/3K4/8/8/8 w - - 0 1");
    movegen.generateKingMoves(&b, &attackTable, &context, countMoveFn);
    try std.testing.expectEqual(@as(usize, 8), context.count);

    // Reset context
    context.count = 0;

    // Test king captures - surrounded by enemy pieces
    try utils.parseFEN(&b, "8/8/2ppp3/2pKp3/2ppp3/8/8/8 w - - 0 1");
    movegen.generateKingMoves(&b, &attackTable, &context, countMoveFn);
    try std.testing.expectEqual(@as(usize, 8), context.count);
}

test "rook move generation - open board" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    try utils.parseFEN(&b, "8/8/8/8/3R4/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, false); // false for rook
    try std.testing.expectEqual(@as(usize, 14), context.count);
}

test "rook move generation - blocked by friendly pieces" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    try utils.parseFEN(&b, "8/8/8/3P4/2PRP3/3P4/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, false);
    try std.testing.expectEqual(@as(usize, 0), context.count);
}

test "rook move generation - captures" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    const Context = struct {
        captures: usize = 0,
        quiet: usize = 0,

        fn countMove(self: *@This(), move: movegen.Move) void {
            switch (move.moveType) {
                .capture => self.captures += 1,
                .quiet => self.quiet += 1,
                else => {},
            }
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    try utils.parseFEN(&b, "8/8/3p4/8/2R1p3/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, false);
    try std.testing.expectEqual(@as(usize, 1), context.captures);
    try std.testing.expectEqual(@as(usize, 10), context.quiet);
}

test "bishop move generation - open board" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    try utils.parseFEN(&b, "8/8/8/8/3B4/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, true); // true for bishop
    try std.testing.expectEqual(@as(usize, 13), context.count);
}

test "bishop move generation - blocked by friendly pieces" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    try utils.parseFEN(&b, "8/8/2P5/3B4/2P5/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, true);
    try std.testing.expectEqual(@as(usize, 7), context.count);
}

test "bishop move generation - captures" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    const Context = struct {
        captures: usize = 0,
        quiet: usize = 0,

        fn countMove(self: *@This(), move: movegen.Move) void {
            switch (move.moveType) {
                .capture => self.captures += 1,
                .quiet => self.quiet += 1,
                else => {},
            }
        }
    };

    var context = Context{};
    const countMoveFn = struct {
        fn add(ctx: *Context, move: movegen.Move) void {
            ctx.countMove(move);
        }
    }.add;

    try utils.parseFEN(&b, "8/8/5p2/4B3/2p5/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, true);
    try std.testing.expectEqual(@as(usize, 1), context.captures);
    try std.testing.expectEqual(@as(usize, 10), context.quiet);
}

test "sliding pieces - multiple pieces" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

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

    try utils.parseFEN(&b, "8/8/2R2B2/8/3R4/8/8/8 w - - 0 1");

    // Count rook moves
    context.count = 0;
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, false);
    const rookMoves = context.count;

    // Count bishop moves
    context.count = 0;
    movegen.generateSlidingMoves(&b, &attackTable, &context, countMoveFn, true);
    const bishopMoves = context.count;

    try std.testing.expect(rookMoves > 0);
    try std.testing.expect(bishopMoves > 0);
}
