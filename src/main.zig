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
const Perft = @import("perft.zig");

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
// I think the current perft issue lies in how I'm generating attack masks.
// In my C implementation, I intentionally don't include the board edges
// in the attack mask so that we don't get wrapping captures (h2 takes a3)
// but I don't know that I'm accounting for that when making the attack masks.
// I think we will need to bitwise & the result with a board that only contains the
// edge squares, and this should fix the problem.
pub fn main() !void {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Set up position
    try utils.parseFEN(&b, board.Position.kiwiPete);

    var perft = Perft.Perft.init(&b, &attack_table);
    perft.debugMoveGeneration();

    // Run perft test
    const timer = Perft.Timer.start();
    const nodes = perft.perftCount(1);
    const elapsed = timer.elapsed();

    std.debug.print("Perft(1) found {d} nodes in {d}ms\n", .{ nodes, elapsed });
}

test "make move - quiet moves" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, board.Position.start);

    // Test a simple pawn move
    const move = movegen.Move{
        .from = .e2,
        .to = .e3,
        .piece = .P,
        .moveType = .quiet,
    };

    try b.makeMove(move, &attackTable);

    // Verify the move
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e2)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e3)));
    try std.testing.expect(b.sideToMove == .black);
}

test "make move - captures" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1");

    // Test a capture
    const move = movegen.Move{
        .from = .e4,
        .to = .d5,
        .piece = .P,
        .moveType = .capture,
    };

    try b.makeMove(move, &attackTable);

    // Verify the capture
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e4)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.d5)));
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.p)], @intFromEnum(board.Square.d5)));
    try std.testing.expect(b.sideToMove == .black);
}

test "make move - en passant" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1");

    // Make a black pawn double push
    const doublePush = movegen.Move{
        .from = .d7,
        .to = .d5,
        .piece = .p,
        .moveType = .doublePush,
    };

    try b.makeMove(doublePush, &attackTable);

    // Verify en passant square is set
    try std.testing.expect(b.enpassant == .d6);

    // Make the en passant capture
    const enPassant = movegen.Move{
        .from = .e4,
        .to = .d5,
        .piece = .P,
        .moveType = .enpassant,
    };

    try b.makeMove(enPassant, &attackTable);

    // Verify the en passant capture
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e4)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.d5)));
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.p)], @intFromEnum(board.Square.d5)));
    try std.testing.expect(b.enpassant == .noSquare);
}

test "make move - promotion" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, "rnbqkbnr/ppppppPp/8/8/8/8/PPPPPP1P/RNBQKBNR w KQkq - 0 1");

    // Test a promotion to queen
    const move = movegen.Move{
        .from = .g7,
        .to = .g8,
        .piece = .P,
        .promotionPiece = .queen,
        .moveType = .promotion,
    };

    try b.makeMove(move, &attackTable);

    // Verify the promotion
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.g7)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.Q)], @intFromEnum(board.Square.g8)));
    try std.testing.expect(b.sideToMove == .black);
}

test "make move - castling rights" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1");

    // Move the white king
    const move = movegen.Move{
        .from = .e1,
        .to = .e2,
        .piece = .K,
        .moveType = .quiet,
    };

    try b.makeMove(move, &attackTable);

    // Verify castling rights are updated
    try std.testing.expect(!b.castling.whiteKingside);
    try std.testing.expect(!b.castling.whiteQueenside);
    try std.testing.expect(b.castling.blackKingside);
    try std.testing.expect(b.castling.blackQueenside);
}
test "make move - castling" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test kingside castling with partial castling rights
    try utils.parseFEN(&b, "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ-q - 0 1");

    const kingsideCastle = movegen.Move{
        .from = .e1,
        .to = .g1,
        .piece = board.Piece.K,
        .moveType = .castle,
        .promotionPiece = .none,
    };

    b.makeMoveUnchecked(kingsideCastle);

    // Verify positions after kingside castle
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.K)], @intFromEnum(board.Square.e1)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.K)], @intFromEnum(board.Square.g1)));
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.R)], @intFromEnum(board.Square.h1)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.R)], @intFromEnum(board.Square.f1)));

    // Check partial castling rights were updated correctly
    try std.testing.expect(!b.castling.whiteKingside);
    try std.testing.expect(!b.castling.whiteQueenside);
    try std.testing.expect(!b.castling.blackKingside);
    try std.testing.expect(b.castling.blackQueenside);
    try std.testing.expect(b.sideToMove == board.Side.black);

    // Test another partial castling rights position
    try utils.parseFEN(&b, "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b K-k- - 0 1");

    const queensideCastle = movegen.Move{
        .from = .e8,
        .to = .c8,
        .piece = board.Piece.k,
        .moveType = .castle,
        .promotionPiece = .none,
    };

    b.makeMoveUnchecked(queensideCastle);

    // Verify positions after queenside castle
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.k)], @intFromEnum(board.Square.e8)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.k)], @intFromEnum(board.Square.c8)));
    try std.testing.expectEqual(@as(u1, 0), utils.getBit(b.bitboard[@intFromEnum(board.Piece.r)], @intFromEnum(board.Square.a8)));
    try std.testing.expectEqual(@as(u1, 1), utils.getBit(b.bitboard[@intFromEnum(board.Piece.r)], @intFromEnum(board.Square.d8)));

    // Check partial castling rights were updated correctly
    try std.testing.expect(b.castling.whiteKingside);
    try std.testing.expect(!b.castling.whiteQueenside);
    try std.testing.expect(!b.castling.blackKingside);
    try std.testing.expect(!b.castling.blackQueenside);
    try std.testing.expect(b.sideToMove == board.Side.white);

    // Test occupancy updates
    try std.testing.expect(b.occupancy[@intFromEnum(board.Side.both)] == (b.occupancy[@intFromEnum(board.Side.white)] |
        b.occupancy[@intFromEnum(board.Side.black)]));
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
    try std.testing.expectEqual(@as(usize, 16), context.count);
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

test "queen move generation" {
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

    // Test queen in the middle of an empty board
    try utils.parseFEN(&b, "8/8/8/8/3Q4/8/8/8 w - - 0 1");
    movegen.generateQueenMoves(&b, &attackTable, &context, countMoveFn);
    try std.testing.expectEqual(@as(usize, 27), context.count); // Queen should have 27 possible moves in the center
}

test "move list usage" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Initialize move list
    var moveList = movegen.MoveList.init();

    // Test position with a queen in the center
    try utils.parseFEN(&b, "8/8/8/8/3Q4/8/8/8 w - - 0 1");

    // Generate queen moves directly into the move list
    movegen.generateQueenMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    // Verify moves were added
    try std.testing.expect(!moveList.isEmpty());
    try std.testing.expect(moveList.count > 0);

    // Clear the list
    moveList.clear();
    try std.testing.expect(moveList.isEmpty());
}

test "pawn double push generation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up initial position
    try utils.parseFEN(&b, board.Position.start);

    var moveList = movegen.MoveList.init();

    // Generate only pawn moves
    movegen.generatePawnMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    // Count single and double pushes
    var singlePushes: usize = 0;
    var doublePushes: usize = 0;

    for (moveList.getMoves()) |move| {
        if (move.moveType == .doublePush) {
            doublePushes += 1;
            std.debug.print("Double push from {s} to {s}\n", .{ @tagName(move.from), @tagName(move.to) });
        } else if (move.moveType == .quiet) {
            singlePushes += 1;
            std.debug.print("Single push from {s} to {s}\n", .{ @tagName(move.from), @tagName(move.to) });
        }
    }

    std.debug.print("\nTotal moves: {d}\nSingle pushes: {d}\nDouble pushes: {d}\n", .{ moveList.count, singlePushes, doublePushes });

    try std.testing.expectEqual(@as(usize, 8), singlePushes);
    try std.testing.expectEqual(@as(usize, 8), doublePushes);
    try std.testing.expectEqual(@as(usize, 16), moveList.count);
}

test "generate all moves from initial position" {
    // Initialize board and attack table
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up initial position
    try utils.parseFEN(&b, board.Position.start);

    // Create move list to store all moves
    var moveList = movegen.MoveList.init();

    // Generate pawn moves
    movegen.generatePawnMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 16), moveList.count); // Each pawn can move 1 or 2 squares

    // Generate knight moves
    movegen.generateKnightMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 20), moveList.count); // 16 pawn moves + 4 knight moves (2 per knight)

    // Generate bishop moves
    movegen.generateSlidingMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback, true);
    try std.testing.expectEqual(@as(usize, 20), moveList.count); // No legal bishop moves in initial position

    // Generate rook moves
    movegen.generateSlidingMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback, false);
    try std.testing.expectEqual(@as(usize, 20), moveList.count); // No legal rook moves in initial position

    // Generate queen moves
    movegen.generateQueenMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 20), moveList.count); // No legal queen moves in initial position

    // Generate king moves
    movegen.generateKingMoves(&b, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 20), moveList.count); // No legal king moves in initial position

    // Print all moves for debugging
    moveList.print();

    // Verify specific move types
    var pawnMoves: usize = 0;
    var knightMoves: usize = 0;
    var doublePushes: usize = 0;

    for (moveList.getMoves()) |move| {
        switch (move.piece) {
            .P, .p => {
                pawnMoves += 1;
                if (move.moveType == .doublePush) {
                    doublePushes += 1;
                }
            },
            .N, .n => knightMoves += 1,
            else => {},
        }
    }

    // Verify counts of specific move types
    try std.testing.expectEqual(@as(usize, 16), pawnMoves);
    try std.testing.expectEqual(@as(usize, 4), knightMoves);
    try std.testing.expectEqual(@as(usize, 8), doublePushes);

    // Test that all moves are either quiet or double pushes (no captures possible in initial position)
    for (moveList.getMoves()) |move| {
        try std.testing.expect(move.moveType == .quiet or move.moveType == .doublePush);
    }

    // Clear the list and verify it's empty
    moveList.clear();
    try std.testing.expect(moveList.isEmpty());
}

test "square coordinate conversion" {
    // Test bottom left corner (a1)
    const a1 = try board.Square.a1.toCoordinates();
    try std.testing.expectEqual(@as(u8, 'a'), a1[0]);
    try std.testing.expectEqual(@as(u8, '1'), a1[1]);
    std.debug.print("a1 passed", .{});

    // Test top right corner (h8)
    const h8 = try board.Square.h8.toCoordinates();
    try std.testing.expectEqual(@as(u8, 'h'), h8[0]);
    try std.testing.expectEqual(@as(u8, '8'), h8[1]);
    std.debug.print("h8 passed", .{});

    // Test white pawn starting squares
    const a2 = try board.Square.a2.toCoordinates();
    try std.testing.expectEqual(@as(u8, 'a'), a2[0]);
    try std.testing.expectEqual(@as(u8, '2'), a2[1]);
    std.debug.print("a2 passed", .{});

    // Test black pawn starting squares
    const e7 = try board.Square.e7.toCoordinates();
    try std.testing.expectEqual(@as(u8, 'e'), e7[0]);
    try std.testing.expectEqual(@as(u8, '7'), e7[1]);
    std.debug.print("e7 passed", .{});
}

test "timer basic functionality" {
    // Test getTimeMs
    const time1 = Perft.getTimeMs();
    const time2 = Perft.getTimeMs();
    try std.testing.expect(time2 >= time1);

    // Test Timer
    var timer = Perft.Timer.start();
    std.time.sleep(10 * std.time.ns_per_ms); // Sleep for 10ms
    const elapsed = timer.elapsed();
    try std.testing.expect(elapsed >= 10);
}

test "timer reset functionality" {
    var timer = Perft.Timer.start();
    std.time.sleep(10 * std.time.ns_per_ms);
    const elapsed1 = timer.elapsedAndReset();
    try std.testing.expect(elapsed1 >= 10);

    std.time.sleep(20 * std.time.ns_per_ms);
    const elapsed2 = timer.elapsed();
    try std.testing.expect(elapsed2 >= 20);
}

test "perft initial position depth 1" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Set up initial position
    try utils.parseFEN(&b, board.Position.start);

    var perft = Perft.Perft.init(&b, &attack_table);
    const nodes = perft.perftCount(2);

    // Initial position should have 20 moves at depth 1
    try std.testing.expectEqual(@as(u64, 20), nodes);
}

test "perft kiwipete position depth 2" {
    var b: board.Board = undefined;
    b.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Set up Kiwipete position
    try utils.parseFEN(&b, board.Position.kiwiPete);

    var perft = Perft.Perft.init(&b, &attack_table);
    const nodes = perft.perftCount(2);

    // Kiwipete position should have 2039 nodes at depth 2
    try std.testing.expectEqual(@as(u64, 2039), nodes);
}
