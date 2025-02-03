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
const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");
const utils = @import("utils.zig");
const Perft = @import("perft.zig");
const magic = @import("magics.zig");
const evaluation = @import("evaluation.zig");
const transposition = @import("transposition.zig");
const search = @import("search.zig");

fn countAttacks(attackBitboard: u64) u32 {
    return @popCount(attackBitboard);
}

// Helper function to print a bitboard for debugging
fn printBitboard(bitboard: u64) void {
    for (0..8) |rank| {
        const displayRank = 8 - rank;
        std.debug.print("  {d}  ", .{displayRank});
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            const bit = utils.getBit(bitboard, square);
            std.debug.print(" {d}", .{bit});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n     a b c d e f g h\n\n", .{});
}

test "pawn attacks white" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center pawn attacks
    {
        const square = @intFromEnum(board.Square.e4);
        const attackBitboard = attackTable.pawn[@intFromEnum(board.Side.white)][square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 2), count); // Expect 2 diagonal attacks

        // Verify specific squares that should be attacked (d5 and f5)
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.d5))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.f5))) != 0);
    }

    // Test edge pawn attacks (a-file)
    {
        const square = @intFromEnum(board.Square.a2);
        const attackBitboard = attackTable.pawn[@intFromEnum(board.Side.white)][square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 1), count); // Expect 1 diagonal attack

        // Verify only b3 is attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.b3))) != 0);
    }

    // Test edge pawn attacks (h-file)
    {
        const square = @intFromEnum(board.Square.h2);
        const attackBitboard = attackTable.pawn[@intFromEnum(board.Side.white)][square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 1), count); // Expect 1 diagonal attack

        // Verify only g3 is attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.g3))) != 0);
    }
}

test "bishop attacks with blocking pieces" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test bishop with blocking pieces
    {
        const square = @intFromEnum(board.Square.e4);
        var occupancy: u64 = 0;

        // Add blocking pieces
        utils.setBit(&occupancy, @intFromEnum(board.Square.c2)); // Block SW
        utils.setBit(&occupancy, @intFromEnum(board.Square.g6)); // Block NE

        const attackBitboard = attacks.getBishopAttacks(square, occupancy, &attackTable);

        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 11), count); // Should include c2 and g6, but not beyond

        // Verify blocked squares are not attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.b1)))) == 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.h7)))) == 0);

        // Verify squares up to and including blockers are attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.c2)))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.g6)))) != 0);
    }
}

test "pawn attacks black" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center pawn attacks
    {
        const square = @intFromEnum(board.Square.e5);
        const attackBitboard = attackTable.pawn[@intFromEnum(board.Side.black)][square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 2), count); // Expect 2 diagonal attacks

        // Verify specific squares that should be attacked (d4 and f4)
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.d4))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.f4))) != 0);
    }

    // Test edge pawn attacks (a-file)
    {
        const square = @intFromEnum(board.Square.a7);
        const attackBitboard = attackTable.pawn[@intFromEnum(board.Side.black)][square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 1), count); // Expect 1 diagonal attack

        // Verify only b6 is attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.b6))) != 0);
    }
}

test "knight attacks" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center knight
    {
        const square = @intFromEnum(board.Square.e4);
        const attackBitboard = attackTable.knight[square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 8), count); // Knight should have 8 possible moves

        // Verify all 8 squares are attacked
        const expected_squares = [_]board.Square{
            .d6, .f6, // Up 2, left/right 1
            .c5, .g5, // Up 1, left/right 2
            .c3, .g3, // Down 1, left/right 2
            .d2, .f2, // Down 2, left/right 1
        };

        for (expected_squares) |target| {
            try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(target)))) != 0);
        }
    }

    // Test corner knight (a1)
    {
        const square = @intFromEnum(board.Square.a1);
        const attackBitboard = attackTable.knight[square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 2), count); // Corner knight only has 2 moves

        // Verify b3 and c2 are attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.b3)))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.c2)))) != 0);
    }
}

test "king attacks" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center king
    {
        const square = @intFromEnum(board.Square.e4);
        const attackBitboard = attackTable.king[square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 8), count); // King should have 8 possible moves

        // Verify all 8 adjacent squares are attacked
        const expected_squares = [_]board.Square{
            .d5, .e5, .f5, // Upper row
            .d4, .f4, // Same row
            .d3, .e3, .f3, // Lower row
        };

        for (expected_squares) |target| {
            try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(target)))) != 0);
        }
    }

    // Test corner king (h8)
    {
        const square = @intFromEnum(board.Square.h8);
        const attackBitboard = attackTable.king[square];
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 3), count); // Corner king only has 3 moves

        // Verify g8, g7, and h7 are attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.g8)))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.g7)))) != 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.h7)))) != 0);
    }
}

test "bishop attacks" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center bishop with empty board
    {
        const square = @intFromEnum(board.Square.e4);
        const attackBitboard = attacks.getBishopAttacks(square, 0, &attackTable);
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 13), count); // Bishop should have 13 possible moves on empty board

        // Test key diagonal squares
        const expected_squares = [_]board.Square{
            .b1, .c2, .d3, .f5, .g6, .h7, // Main diagonal
            .b7, .c6, .d5, .f3, .g2, .h1, // Other diagonal
        };

        for (expected_squares) |target| {
            try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(target)))) != 0);
        }
    }

    // Test bishop with blocking pieces
    {
        const square = @intFromEnum(board.Square.e4);
        var occupancy: u64 = 0;

        // Add blocking pieces
        utils.setBit(&occupancy, @intFromEnum(board.Square.c2)); // Block SW
        utils.setBit(&occupancy, @intFromEnum(board.Square.g6)); // Block NE

        const attackBitboard = attacks.getBishopAttacks(square, occupancy, &attackTable);
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 11), count); // Should have fewer moves due to blocking pieces

        // Verify blocked squares are not attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.b1)))) == 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(board.Square.h7)))) == 0);
    }
}

test "rook attacks" {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test center rook with empty board
    {
        const square = @intFromEnum(board.Square.e4);
        const attackBitboard = attacks.getRookAttacks(square, 0, &attackTable);
        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 14), count); // Rook should have 14 possible moves on empty board

        // Test key squares on each ray
        const expected_squares = [_]board.Square{
            .e1, .e2, .e3, .e5, .e6, .e7, .e8, // Vertical
            .a4, .b4, .c4, .d4, .f4, .g4, .h4, // Horizontal
        };

        for (expected_squares) |target| {
            try std.testing.expect((attackBitboard & (@as(u64, 1) << @intCast(@intFromEnum(target)))) != 0);
        }
    }

    // Test rook with blocking pieces
    {
        const square = @intFromEnum(board.Square.e4);
        var occupancy: u64 = 0;

        // Add blocking pieces
        utils.setBit(&occupancy, @intFromEnum(board.Square.e6)); // Block N
        utils.setBit(&occupancy, @intFromEnum(board.Square.g4)); // Block E

        const attackBitboard = attacks.getRookAttacks(square, occupancy, &attackTable);

        const count = countAttacks(attackBitboard);
        try std.testing.expectEqual(@as(u32, 11), count); // Should have fewer moves due to blocking pieces

        // Verify blocked squares are not attacked
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.e7))) == 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.e8))) == 0);
        try std.testing.expect((attackBitboard & (@as(u64, 1) << @intFromEnum(board.Square.h4))) == 0);
    }
}

test "isSquareAttacked" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up a position where e4 is attacked by multiple pieces
    try utils.parseFEN(&gameBoard, "r1bqkb1r/pppp1ppp/2n2n2/4p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 0 1");

    // Test square under attack
    {
        const square = @intFromEnum(board.Square.e4);
        const isAttacked = attacks.isSquareAttacked(@intCast(square), .white, &gameBoard, &attackTable);
        try std.testing.expect(isAttacked); // e4 should be attacked by black pieces
    }

    // Test square not under attack
    {
        const square = @intFromEnum(board.Square.d4);
        const isAttacked = attacks.isSquareAttacked(@intCast(square), .white, &gameBoard, &attackTable);
        try std.testing.expect(isAttacked); // d4 should not be attacked
    }

    // Test edge case - empty board
    {
        var emptyBoard = board.Board.init();
        const square = @intFromEnum(board.Square.e4);
        const isAttacked = attacks.isSquareAttacked(@intCast(square), .white, &emptyBoard, &attackTable);
        try std.testing.expect(!isAttacked); // No pieces, no attacks
    }
}

test "Square enum conversion" {
    // Test coordinate conversion
    try std.testing.expectEqual([2]u8{ 'e', '2' }, try board.Square.e2.toCoordinates());
    try std.testing.expectEqual([2]u8{ 'a', '1' }, try board.Square.a1.toCoordinates());
    try std.testing.expectEqual([2]u8{ 'h', '8' }, try board.Square.h8.toCoordinates());

    // Test enum values
    try std.testing.expectEqual(@as(u7, 52), @intFromEnum(board.Square.e2));
    try std.testing.expectEqual(@as(u7, 56), @intFromEnum(board.Square.a1));
    try std.testing.expectEqual(@as(u7, 7), @intFromEnum(board.Square.h8));
}

test "Piece properties" {
    // Test piece colors
    try std.testing.expect(board.Piece.P.isWhite());
    try std.testing.expect(board.Piece.K.isWhite());
    try std.testing.expect(!board.Piece.p.isWhite());
    try std.testing.expect(!board.Piece.k.isWhite());

    // Test promotion characters
    try std.testing.expectEqual(@as(u8, 'q'), board.Piece.Q.toPromotionChar());
    try std.testing.expectEqual(@as(u8, 'r'), board.Piece.R.toPromotionChar());
    try std.testing.expectEqual(@as(u8, 'b'), board.Piece.B.toPromotionChar());
    try std.testing.expectEqual(@as(u8, 'n'), board.Piece.N.toPromotionChar());
    try std.testing.expectEqual(@as(u8, ' '), board.Piece.P.toPromotionChar());
}

test "Side properties" {
    // Test side opposites
    try std.testing.expectEqual(board.Side.black, board.Side.white.opposite());
    try std.testing.expectEqual(board.Side.white, board.Side.black.opposite());
    try std.testing.expectEqual(board.Side.both, board.Side.both.opposite());
}

const PiecePosition = struct {
    piece: board.Piece,
    square: board.Square,
};

fn validateTestPosition(b: *const board.Board, expected_pieces: []const PiecePosition) !void {
    // Verify each expected piece
    for (expected_pieces) |piece_info| {
        const bit = utils.getBit(b.bitboard[@intFromEnum(piece_info.piece)], @intCast(@intFromEnum(piece_info.square)));
        if (bit != 1) {
            std.debug.print("Expected {any} on {any}, not found\n", .{ piece_info.piece, piece_info.square });
            return error.InvalidPosition;
        }
    }

    // Verify no unexpected pieces
    var total_pieces: u32 = 0;
    for (b.bitboard, 0..) |bb, i| {
        total_pieces += utils.countBits(bb);

        // Print bitboard if pieces found
        if (bb != 0) {
            std.debug.print("Piece type {d} bitboard:\n", .{i});
            utils.printBitboard(bb);
        }
    }

    if (total_pieces != expected_pieces.len) {
        std.debug.print("Expected {d} pieces, found {d}\n", .{ expected_pieces.len, total_pieces });
        return error.UnexpectedPieces;
    }
}

test "search mate in one with debugging" {
    // Initialize board and attack table
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up the position with error checking
    try utils.parseFEN(&b, "7k/6Q1/8/8/8/8/8/7K w - - 0 1");

    // Verify initial position is valid
    try validateTestPosition(&b, &[_]PiecePosition{
        .{ .piece = .K, .square = .h1 },
        .{ .piece = .k, .square = .h8 },
        .{ .piece = .Q, .square = .g7 },
    });

    // Validate king positions
    try validateKingPosition(&b);

    // Initialize transposition table
    var tt = transposition.TranspositionTable.init();

    // Set up search limits with stricter constraints
    const limits = search.SearchLimits{
        .depth = 4,
        .movetime = 1000,
        .nodes = 10000, // Reduced node limit for testing
        .infinite = false,
        .startTime = std.time.milliTimestamp(),
    };

    std.debug.print("\nStarting search with limits:\n", .{});
    std.debug.print("  Depth: {d}\n", .{limits.depth});
    std.debug.print("  Move time: {d}ms\n", .{limits.movetime.?});
    std.debug.print("  Node limit: {d}\n", .{limits.nodes.?});

    // Create a timer for overall search time tracking
    const startTime = std.time.milliTimestamp();

    // Perform search with error handling
    var result = search.SearchResult{};
    result = try search.startSearch(&b, &attackTable, &tt, limits);

    const endTime = std.time.milliTimestamp();
    const searchTime = endTime - startTime;

    // Debug output
    std.debug.print("\nSearch completed in {d}ms\n", .{searchTime});
    std.debug.print("Search result:\n", .{});
    std.debug.print("  Score: {d}\n", .{result.score});
    std.debug.print("  Depth: {d}\n", .{result.depth});
    std.debug.print("  Nodes: {d}\n", .{result.nodes});

    if (result.bestMove) |move| {
        const sourceCoords = try move.source.toCoordinates();
        const targetCoords = try move.target.toCoordinates();
        std.debug.print("  Best move: {c}{c}{c}{c}\n", .{ sourceCoords[0], sourceCoords[1], targetCoords[0], targetCoords[1] });
    } else {
        std.debug.print("  No best move found!\n", .{});
    }

    // Verify search completed within time limit
    try std.testing.expect(searchTime <= limits.movetime.? * 2); // Allow some buffer

    // Verify results
    try std.testing.expect(result.score > 20000); // Mate score
    try std.testing.expect(result.bestMove != null);

    if (result.bestMove) |move| {
        // Check both possible mate moves
        const isMateMoveH7 = move.source == .g7 and move.target == .h7;
        const isMateMoveH8 = move.source == .g7 and move.target == .h8;
        try std.testing.expect(isMateMoveH7 or isMateMoveH8);
    }
}

fn validateKingPosition(gameBoard: *const board.Board) !void {
    const whiteKingBoard = gameBoard.bitboard[@intFromEnum(board.Piece.K)];
    const blackKingBoard = gameBoard.bitboard[@intFromEnum(board.Piece.k)];

    // Ensure exactly one king of each color
    if (utils.countBits(whiteKingBoard) != 1 or utils.countBits(blackKingBoard) != 1) {
        return error.InvalidKingCount;
    }

    // Verify king positions are valid
    const whiteKingIndex = utils.getLSBindex(whiteKingBoard);
    const blackKingIndex = utils.getLSBindex(blackKingBoard);

    if (whiteKingIndex < 0 or whiteKingIndex >= 64 or
        blackKingIndex < 0 or blackKingIndex >= 64)
    {
        return error.InvalidKingPosition;
    }
}

test "search mate in two" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Setup a mate in two position:
    // White rook on h7, king on g2, black king on h8
    try utils.parseFEN(&b, "7k/7R/8/8/8/8/6K1/8 w - - 0 1");

    var tt = transposition.TranspositionTable.init();
    const limits = search.SearchLimits{
        .depth = 5, // Need at least depth 4 to find mate in 2
        .movetime = 2000,
    };

    const result = try search.startSearch(&b, &attackTable, &tt, limits);

    try std.testing.expect(result.score > 28000);
    try std.testing.expect(result.bestMove != null);

    if (result.bestMove) |move| {
        // First move should be Rh7-h6, forcing black king to g8
        try std.testing.expectEqual(move.source, .h7);
        try std.testing.expectEqual(move.target, .h6);
    }
}

test "search should find obvious captures" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Position with free queen capture
    try utils.parseFEN(&b, "rnb1kbnr/pppp1ppp/8/4p3/3q4/2N5/PPPPPPPP/R1BQKBNR w KQkq - 0 1");

    var tt = transposition.TranspositionTable.init();
    const limits = search.SearchLimits{
        .depth = 3,
        .movetime = 1000,
    };

    const result = try search.startSearch(&b, &attackTable, &tt, limits);
    try std.testing.expect(result.bestMove != null);

    if (result.bestMove) |move| {
        // Should capture the queen with the knight
        try std.testing.expectEqual(move.source, .c3);
        try std.testing.expectEqual(move.target, .d4);
        try std.testing.expectEqual(move.moveType, .capture);
    }
}

test "search quiet position evaluation" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Equal, quiet middle game position
    try utils.parseFEN(&b, "r1bqkb1r/pppp1ppp/2n2n2/4p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 0 1");

    var tt = transposition.TranspositionTable.init();
    const limits = search.SearchLimits{
        .depth = 4,
        .movetime = 1000,
    };

    const result = try search.startSearch(&b, &attackTable, &tt, limits);

    // Score should be relatively close to zero in this equal position
    try std.testing.expect(result.score > -100 and result.score < 100);
}

test "search time management" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Use starting position
    try utils.parseFEN(&b, board.Position.start);

    var tt = transposition.TranspositionTable.init();
    const limits = search.SearchLimits{
        .depth = 20, // Deep depth
        .movetime = 100, // But only 100ms time
    };

    const startTime = std.time.milliTimestamp();
    const result = try search.startSearch(&b, &attackTable, &tt, limits);
    const elapsed = std.time.milliTimestamp() - startTime;

    // Should stop within reasonable time of limit
    try std.testing.expect(elapsed >= 100 and elapsed < 150);

    // Should still have found a reasonable move
    try std.testing.expect(result.bestMove != null);
}

test "search transposition table usage" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&b, board.Position.start);

    var tt = transposition.TranspositionTable.init();
    const info = search.SearchInfo{};

    // First search
    const limits1 = search.SearchLimits{ .depth = 5, .movetime = 1000 };
    _ = try search.startSearch(&b, &attackTable, &tt, limits1);
    const initial_probes = info.tt_probes;
    const initial_hits = info.tt_hits;

    // Second search (should use TT entries)
    const limits2 = search.SearchLimits{ .depth = 5, .movetime = 1000 };
    _ = try search.startSearch(&b, &attackTable, &tt, limits2);

    // Should see increased TT usage in second search
    try std.testing.expect(info.tt_probes > initial_probes);
    try std.testing.expect(info.tt_hits > initial_hits);
}

test "search move ordering" {
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Position with obvious captures and quiet moves
    try utils.parseFEN(&b, "r1bqkb1r/pppp1ppp/2n5/4p3/3Pn3/2N5/PPP1PPPP/R1BQKBNR w KQkq - 0 1");

    var tt = transposition.TranspositionTable.init();
    const info = search.SearchInfo{};

    const limits = search.SearchLimits{
        .depth = 4,
        .movetime = 1000,
    };

    const result = try search.startSearch(&b, &attackTable, &tt, limits);

    // Capturing the knight should be considered early
    try std.testing.expect(result.bestMove != null);
    if (result.bestMove) |move| {
        try std.testing.expectEqual(move.moveType, .capture);
    }

    // Should have reasonable node count
    try std.testing.expect(info.nodes > 1000);
}
test "Castling rights" {
    var rights = board.CastlingRights{};

    // Test initial state
    try std.testing.expect(!rights.whiteKingside);
    try std.testing.expect(!rights.whiteQueenside);
    try std.testing.expect(!rights.blackKingside);
    try std.testing.expect(!rights.blackQueenside);

    // Test all rights enabled
    rights = board.CastlingRights.all();
    try std.testing.expect(rights.whiteKingside);
    try std.testing.expect(rights.whiteQueenside);
    try std.testing.expect(rights.blackKingside);
    try std.testing.expect(rights.blackQueenside);
}

test "Board initialization" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test empty board state
    try std.testing.expectEqual(@as(u64, 0), gameBoard.occupancy[0]);
    try std.testing.expectEqual(@as(u64, 0), gameBoard.occupancy[1]);
    try std.testing.expectEqual(@as(u64, 0), gameBoard.occupancy[2]);
    try std.testing.expectEqual(board.Side.white, gameBoard.sideToMove);
    try std.testing.expectEqual(board.Square.noSquare, gameBoard.enpassant);

    // Test standard starting position
    try utils.parseFEN(&gameBoard, board.Position.start);
    try std.testing.expect(gameBoard.bitboard[@intFromEnum(board.Piece.P)] != 0); // White pawns exist
    try std.testing.expect(gameBoard.bitboard[@intFromEnum(board.Piece.p)] != 0); // Black pawns exist
    try std.testing.expectEqual(board.Side.white, gameBoard.sideToMove);
    try std.testing.expect(gameBoard.castling.whiteKingside);
}

test "Board move making - pawn moves" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&gameBoard, board.Position.start);
    const initialBoard = gameBoard;

    // Test simple pawn push
    {
        const move = movegen.Move{
            .source = .e2,
            .target = .e4,
            .piece = .P,
            .moveType = .doublePush,
        };

        try gameBoard.makeMove(move);

        // Verify pawn moved
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e4)) == 1);
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e2)) == 0);

        // Verify en passant square is set
        try std.testing.expectEqual(board.Square.e3, gameBoard.enpassant);

        // Verify side to move changed
        try std.testing.expectEqual(board.Side.black, gameBoard.sideToMove);
    }

    // Reset and test pawn capture
    gameBoard = initialBoard;
    try utils.parseFEN(&gameBoard, "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2");

    {
        const move = movegen.Move{
            .source = .e4,
            .target = .d5,
            .piece = .P,
            .moveType = .capture,
        };

        try gameBoard.makeMove(move);

        // Verify capture occurred
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.d5)) == 1);
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.p)], @intFromEnum(board.Square.d5)) == 0);
    }
}

test "Board move making - castling" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Setup position ready for castling
    try utils.parseFEN(&gameBoard, "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");

    // Test kingside castling
    {
        const move = movegen.Move{
            .source = .e1,
            .target = .g1,
            .piece = .K,
            .moveType = .castle,
        };

        try gameBoard.makeMove(move);

        // Verify king moved
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.K)], @intFromEnum(board.Square.g1)) == 1);
        // Verify rook moved
        try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.R)], @intFromEnum(board.Square.f1)) == 1);

        // Verify castling rights updated
        try std.testing.expect(!gameBoard.castling.whiteKingside);
        try std.testing.expect(!gameBoard.castling.whiteQueenside);
    }
}

test "Board occupancy updates" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    try utils.parseFEN(&gameBoard, board.Position.start);

    // Get initial occupancy
    const initialWhiteOcc = gameBoard.occupancy[@intFromEnum(board.Side.white)];
    const initialBlackOcc = gameBoard.occupancy[@intFromEnum(board.Side.black)];
    const initialTotalOcc = gameBoard.occupancy[@intFromEnum(board.Side.both)];

    // Make a move
    const move = movegen.Move{
        .source = .e2,
        .target = .e4,
        .piece = .P,
        .moveType = .doublePush,
    };

    try gameBoard.makeMove(move);

    // Verify occupancy updated correctly
    try std.testing.expect(gameBoard.occupancy[@intFromEnum(board.Side.white)] != initialWhiteOcc);
    try std.testing.expectEqual(initialBlackOcc, gameBoard.occupancy[@intFromEnum(board.Side.black)]);
    try std.testing.expect(gameBoard.occupancy[@intFromEnum(board.Side.both)] != initialTotalOcc);

    // Verify both = white | black
    try std.testing.expectEqual(gameBoard.occupancy[@intFromEnum(board.Side.white)] | gameBoard.occupancy[@intFromEnum(board.Side.black)], gameBoard.occupancy[@intFromEnum(board.Side.both)]);
}

test "Board en passant capture" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Setup position with en passant possibility
    try utils.parseFEN(&gameBoard, "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 1");

    const move = movegen.Move{
        .source = .e5,
        .target = .f6,
        .piece = .P,
        .moveType = .enpassant,
    };

    try gameBoard.makeMove(move);

    // Verify capturing pawn moved
    try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.f6)) == 1);
    // Verify captured pawn removed
    try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.p)], @intFromEnum(board.Square.f5)) == 0);
}

test "Board pawn promotion" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Setup position with pawn about to promote
    try utils.parseFEN(&gameBoard, "8/4P3/8/8/8/8/8/8 w - - 0 1");

    const move = movegen.Move{
        .source = .e7,
        .target = .e8,
        .piece = .P,
        .promotionPiece = .queen,
        .moveType = .promotion,
    };

    try gameBoard.makeMove(move);

    // Verify pawn was replaced with queen
    try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.P)], @intFromEnum(board.Square.e7)) == 0);
    try std.testing.expect(utils.getBit(gameBoard.bitboard[@intFromEnum(board.Piece.Q)], @intFromEnum(board.Square.e8)) == 1);
}

test "material scores" {
    // Test basic piece values
    try std.testing.expectEqual(@as(i32, 100), evaluation.MaterialScore.getScore(.P));
    try std.testing.expectEqual(@as(i32, -100), evaluation.MaterialScore.getScore(.p));
    try std.testing.expectEqual(@as(i32, 320), evaluation.MaterialScore.getScore(.N));
    try std.testing.expectEqual(@as(i32, -320), evaluation.MaterialScore.getScore(.n));
    try std.testing.expectEqual(@as(i32, 330), evaluation.MaterialScore.getScore(.B));
    try std.testing.expectEqual(@as(i32, -330), evaluation.MaterialScore.getScore(.b));
    try std.testing.expectEqual(@as(i32, 500), evaluation.MaterialScore.getScore(.R));
    try std.testing.expectEqual(@as(i32, -500), evaluation.MaterialScore.getScore(.r));
    try std.testing.expectEqual(@as(i32, 900), evaluation.MaterialScore.getScore(.Q));
    try std.testing.expectEqual(@as(i32, -900), evaluation.MaterialScore.getScore(.q));
    try std.testing.expectEqual(@as(i32, 20000), evaluation.MaterialScore.getScore(.K));
    try std.testing.expectEqual(@as(i32, -20000), evaluation.MaterialScore.getScore(.k));
}

test "positional scores - pawns" {
    const is_endgame = false;

    // Test central pawns are worth more than edge pawns
    const e4_score = evaluation.PositionalScore.getScore(.P, @intFromEnum(board.Square.e4), is_endgame);
    const a4_score = evaluation.PositionalScore.getScore(.P, @intFromEnum(board.Square.a4), is_endgame);
    try std.testing.expect(e4_score > a4_score);

    // Test advancing pawns are worth more
    const e2_score = evaluation.PositionalScore.getScore(.P, @intFromEnum(board.Square.e2), is_endgame);
    const e4_score_2 = evaluation.PositionalScore.getScore(.P, @intFromEnum(board.Square.e4), is_endgame);
    try std.testing.expect(e4_score_2 > e2_score);

    // Test black pawn scores are negatives of white pawn scores
    const black_e7_score = evaluation.PositionalScore.getScore(.p, @intFromEnum(board.Square.e7), is_endgame);
    const white_e2_score = evaluation.PositionalScore.getScore(.P, @intFromEnum(board.Square.e2), is_endgame);
    try std.testing.expectEqual(-white_e2_score, black_e7_score);
}

test "positional scores - knights" {
    const is_endgame = false;

    // Test central knights are worth more than corner knights
    const e4_score = evaluation.PositionalScore.getScore(.N, @intFromEnum(board.Square.e4), is_endgame);
    const a1_score = evaluation.PositionalScore.getScore(.N, @intFromEnum(board.Square.a1), is_endgame);
    try std.testing.expect(e4_score > a1_score);

    // Test black knight scores are negatives of white knight scores
    const black_b8_score = evaluation.PositionalScore.getScore(.n, @intFromEnum(board.Square.b8), is_endgame);
    const white_b1_score = evaluation.PositionalScore.getScore(.N, @intFromEnum(board.Square.b1), is_endgame);
    try std.testing.expectEqual(-white_b1_score, black_b8_score);
}

test "positional scores - bishops" {
    const is_endgame = false;

    // Test bishops on long diagonals are worth more
    const c4_score = evaluation.PositionalScore.getScore(.B, @intFromEnum(board.Square.c4), is_endgame);
    const e4_score = evaluation.PositionalScore.getScore(.B, @intFromEnum(board.Square.e4), is_endgame);
    try std.testing.expect(c4_score > e4_score);

    // Test black bishop scores are negatives of white bishop scores
    const black_c5_score = evaluation.PositionalScore.getScore(.b, @intFromEnum(board.Square.c5), is_endgame);
    const white_c4_score = evaluation.PositionalScore.getScore(.B, @intFromEnum(board.Square.c4), is_endgame);
    try std.testing.expectEqual(-white_c4_score, black_c5_score);
}

test "positional scores - rooks" {
    const is_endgame = false;

    // Test rooks on 7th rank are worth more
    const e7_score = evaluation.PositionalScore.getScore(.R, @intFromEnum(board.Square.e7), is_endgame);
    const e4_score = evaluation.PositionalScore.getScore(.R, @intFromEnum(board.Square.e4), is_endgame);
    try std.testing.expect(e7_score > e4_score);

    // Test black rook scores are negatives of white rook scores
    const black_a8_score = evaluation.PositionalScore.getScore(.r, @intFromEnum(board.Square.a8), is_endgame);
    const white_a1_score = evaluation.PositionalScore.getScore(.R, @intFromEnum(board.Square.a1), is_endgame);
    try std.testing.expectEqual(-white_a1_score, black_a8_score);
}

test "positional scores - queens" {
    const is_endgame = false;

    // Test central queens are worth more than corner queens
    const e4_score = evaluation.PositionalScore.getScore(.Q, @intFromEnum(board.Square.e4), is_endgame);
    const h1_score = evaluation.PositionalScore.getScore(.Q, @intFromEnum(board.Square.h1), is_endgame);
    try std.testing.expect(e4_score > h1_score);

    // Test black queen scores are negatives of white queen scores
    const black_d8_score = evaluation.PositionalScore.getScore(.q, @intFromEnum(board.Square.d8), is_endgame);
    const white_d1_score = evaluation.PositionalScore.getScore(.Q, @intFromEnum(board.Square.d1), is_endgame);
    try std.testing.expectEqual(-white_d1_score, black_d8_score);
}

test "positional scores - kings" {
    const is_endgame = false;

    // Test kings on back rank are worth more in middlegame
    const e1_score = evaluation.PositionalScore.getScore(.K, @intFromEnum(board.Square.e1), is_endgame);
    const e4_score = evaluation.PositionalScore.getScore(.K, @intFromEnum(board.Square.e4), is_endgame);
    try std.testing.expect(e1_score > e4_score);

    // Test endgame scoring differs
    const e1_endgame = evaluation.PositionalScore.getScore(.K, @intFromEnum(board.Square.e1), true);
    const e4_endgame = evaluation.PositionalScore.getScore(.K, @intFromEnum(board.Square.e4), true);
    try std.testing.expect(@abs(e1_endgame - e4_endgame) < @abs(e1_score - e4_score));
}

test "endgame detection" {
    var gameBoard = board.Board.init();

    // Test starting position is not endgame
    try utils.parseFEN(&gameBoard, board.Position.start);
    try std.testing.expect(!evaluation.isEndgame(&gameBoard));

    // Test K+P vs K is endgame
    try utils.parseFEN(&gameBoard, "8/4P3/8/8/3k4/8/8/4K3 w - - 0 1");
    try std.testing.expect(evaluation.isEndgame(&gameBoard));

    // Test position with single queen is endgame
    try utils.parseFEN(&gameBoard, "8/8/8/3Q4/3k4/8/8/4K3 w - - 0 1");
    try std.testing.expect(evaluation.isEndgame(&gameBoard));

    // Test position with queens and rooks is not endgame
    try utils.parseFEN(&gameBoard, "8/8/8/3Q4/3k4/4r3/8/4K3 w - - 0 1");
    try std.testing.expect(!evaluation.isEndgame(&gameBoard));
}

test "full position evaluation" {
    var gameBoard = board.Board.init();

    // Test starting position is equal
    try utils.parseFEN(&gameBoard, board.Position.start);
    const start_eval = evaluation.evaluate(&gameBoard);
    try std.testing.expect(@abs(start_eval) < 100); // Should be roughly equal

    // Test position with extra pawn
    try utils.parseFEN(&gameBoard, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPP1/RNBQKBNR b KQkq - 0 1");
    const pawn_up = evaluation.evaluate(&gameBoard);
    try std.testing.expect(pawn_up < -50); // Black should be better

    // Test position with better piece placement
    try utils.parseFEN(&gameBoard, "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1");
    const center_pawns = evaluation.evaluate(&gameBoard);
    try std.testing.expect(@abs(center_pawns) < 50); // Should be roughly equal with good central pawns

    // Test mate in one position
    try utils.parseFEN(&gameBoard, "7k/3Q4/7K/8/8/8/8/8 w - - 0 1");
    const mate_position = evaluation.evaluate(&gameBoard);
    try std.testing.expect(mate_position > 5000); // Should be very good for white
}

test "evaluation notation" {
    // Test positive evaluations
    try std.testing.expectEqual("+1.00", evaluation.getEvalNotation(100));
    try std.testing.expectEqual("+2.50", evaluation.getEvalNotation(250));

    // Test negative evaluations
    try std.testing.expectEqual("-1.00", evaluation.getEvalNotation(-100));
    try std.testing.expectEqual("-2.50", evaluation.getEvalNotation(-250));

    // Test small evaluations
    try std.testing.expectEqual("+0.25", evaluation.getEvalNotation(25));
    try std.testing.expectEqual("-0.25", evaluation.getEvalNotation(-25));
}

test "evaluation text" {
    // Test clear advantages
    try std.testing.expectEqual("White is better", evaluation.getEvalText(200));
    try std.testing.expectEqual("Black is better", evaluation.getEvalText(-200));

    // Test equal positions
    try std.testing.expectEqual("Equal position", evaluation.getEvalText(0));
    try std.testing.expectEqual("Equal position", evaluation.getEvalText(50));
    try std.testing.expectEqual("Equal position", evaluation.getEvalText(-50));
}

// Helper function to count specific move types in a move list
fn countMoveTypes(moves: []const movegen.Move, moveType: movegen.MoveType) usize {
    var count: usize = 0;
    for (moves) |move| {
        if (move.moveType == moveType) count += 1;
    }
    return count;
}

// Helper function to verify a specific move exists in the move list
fn moveExists(moves: []const movegen.Move, source: board.Square, target: board.Square, piece: board.Piece, moveType: movegen.MoveType) bool {
    for (moves) |move| {
        if (move.source == source and
            move.target == target and
            move.piece == piece and
            move.moveType == moveType) return true;
    }
    return false;
}

// Helper function to setup a board position
fn setupPosition(gameBoard: *board.Board, fen: []const u8) !void {
    try utils.parseFEN(gameBoard, fen);
    gameBoard.updateOccupancy(); // Ensure occupancy arrays are updated
}

test "pawn moves - basic pushes" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test initial white pawn moves
    try setupPosition(&gameBoard, "8/8/8/8/8/8/P7/8 w - - 0 1");
    movegen.generatePawnMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    try std.testing.expectEqual(@as(usize, 2), moveList.count); // Single and double push
    try std.testing.expect(moveExists(moveList.getMoves(), .a2, .a3, .P, .quiet));
    try std.testing.expect(moveExists(moveList.getMoves(), .a2, .a4, .P, .doublePush));

    // Test blocked pawn
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/8/8/p7/P7/8 w - - 0 1");
    movegen.generatePawnMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 0), moveList.count); // No legal moves
}

test "pawn moves - captures" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test basic pawn captures
    try setupPosition(&gameBoard, "8/8/8/8/8/1p1p4/2P5/8 w - - 0 1");
    movegen.generatePawnMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    try std.testing.expectEqual(@as(usize, 3), moveList.count); // Two captures and one push
    try std.testing.expect(moveExists(moveList.getMoves(), .c2, .b3, .P, .capture));
    try std.testing.expect(moveExists(moveList.getMoves(), .c2, .d3, .P, .capture));
}

test "pawn moves - promotions" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test pawn promotions
    try setupPosition(&gameBoard, "8/P7/8/8/8/8/8/8 w - - 0 1");
    movegen.generatePawnMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    try std.testing.expectEqual(@as(usize, 4), moveList.count); // Four promotion options

    // Verify all promotion pieces
    var found_queen = false;
    var found_rook = false;
    var found_bishop = false;
    var found_knight = false;

    for (moveList.getMoves()) |move| {
        if (move.moveType != .promotion) continue;
        switch (move.promotionPiece) {
            .queen => found_queen = true,
            .rook => found_rook = true,
            .bishop => found_bishop = true,
            .knight => found_knight = true,
            .none => {},
        }
    }

    try std.testing.expect(found_queen and found_rook and found_bishop and found_knight);
}

test "pawn moves - en passant" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test en passant captures
    try setupPosition(&gameBoard, "8/8/8/Pp6/8/8/8/8 w - b6 0 1");
    movegen.generatePawnMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);

    try std.testing.expectEqual(@as(usize, 2), moveList.count); // Regular push and en passant
    try std.testing.expect(moveExists(moveList.getMoves(), .a5, .b6, .P, .enpassant));
}

test "knight moves" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test knight in center
    try setupPosition(&gameBoard, "8/8/8/8/4N3/8/8/8 w - - 0 1");
    movegen.generateKnightMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 8), moveList.count); // 8 possible moves

    // Test knight with captures
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/3p1p2/8/4N3/8/8/8 w - - 0 1");
    movegen.generateKnightMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expect(countMoveTypes(moveList.getMoves(), .capture) == 2);
}

test "bishop moves" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test bishop in center
    try setupPosition(&gameBoard, "8/8/8/8/4B3/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback, true);
    try std.testing.expectEqual(@as(usize, 13), moveList.count); // 13 possible moves

    // Test bishop with blocks and captures
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/2p5/8/4B3/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback, true);
    try std.testing.expect(countMoveTypes(moveList.getMoves(), .capture) == 1);
}

test "rook moves" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test rook in center
    try setupPosition(&gameBoard, "8/8/8/8/4R3/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback, false);
    try std.testing.expectEqual(@as(usize, 14), moveList.count); // 14 possible moves

    // Test rook with blocks and captures
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/8/p3R3/8/8/8 w - - 0 1");
    movegen.generateSlidingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback, false);
    try std.testing.expect(countMoveTypes(moveList.getMoves(), .capture) == 1);
}

test "queen moves" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test queen in center
    try setupPosition(&gameBoard, "8/8/8/8/4Q3/8/8/8 w - - 0 1");
    movegen.generateQueenMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 27), moveList.count); // 27 possible moves (13 bishop + 14 rook)

    // Test queen with blocks and captures
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/3p4/4Q3/8/8/8 w - - 0 1");
    movegen.generateQueenMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expect(countMoveTypes(moveList.getMoves(), .capture) == 1);
}

test "king moves - basic" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test king in center
    try setupPosition(&gameBoard, "8/8/8/8/4K3/8/8/8 w - - 0 1");
    movegen.generateKingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expectEqual(@as(usize, 8), moveList.count); // 8 possible moves

    // Test king with captures
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/3p4/4K3/8/8/8 w - - 0 1");
    movegen.generateKingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expect(countMoveTypes(moveList.getMoves(), .capture) == 1);
}

test "king moves - castling" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();
    var moveList = movegen.MoveList.init();

    // Test kingside castling
    try setupPosition(&gameBoard, "8/8/8/8/8/8/8/4K2R w K - 0 1");
    movegen.generateKingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expect(moveExists(moveList.getMoves(), .e1, .g1, .K, .castle));

    // Test queenside castling
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/8/8/8/8/R3K3 w Q - 0 1");
    movegen.generateKingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    try std.testing.expect(moveExists(moveList.getMoves(), .e1, .c1, .K, .castle));

    // Test blocked castling
    moveList.clear();
    try setupPosition(&gameBoard, "8/8/8/8/8/8/8/4K1NR w K - 0 1");
    movegen.generateKingMoves(&gameBoard, &attackTable, &moveList, movegen.MoveList.addMoveCallback);
    for (moveList.getMoves()) |move| {
        try std.testing.expect(move.moveType != .castle);
    }
}

test "move list capacity" {
    var moveList = movegen.MoveList.init();
    const start_capacity = moveList.moves.len;
    try std.testing.expect(start_capacity >= 256); // Should be able to hold max possible moves

    moveList.clear();
    try std.testing.expectEqual(@as(usize, 0), moveList.count);
}

test "legal move validation" {
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Test basic legal move
    try setupPosition(&gameBoard, "8/8/8/8/8/8/P7/8 w - - 0 1");
    const legal_move = movegen.Move{
        .source = .a2,
        .target = .a3,
        .piece = .P,
        .moveType = .quiet,
    };
    try std.testing.expect(movegen.isMoveLegal(&gameBoard, legal_move, &attackTable));

    // Test illegal move (moving into check)
    try setupPosition(&gameBoard, "8/8/8/8/8/r7/P7/K7 w - - 0 1");
    const illegal_move = movegen.Move{
        .source = .a1,
        .target = .b1,
        .piece = .K,
        .moveType = .quiet,
    };
    try std.testing.expect(!movegen.isMoveLegal(&gameBoard, illegal_move, &attackTable));
}

//test "perft regression test - kiwipete position" {
//    var b = board.Board.init();
//    var attack_table: attacks.AttackTable = undefined;
//    attack_table.init();
//
//    // Test structure for known positions
//    const PerftTest = struct {
//        fen: []const u8,
//        depth: u32,
//        expected_nodes: u64,
//    };
//
//    // Known good positions and their node counts
//    const test_positions = [_]PerftTest{
//        .{
//            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
//            .depth = 1,
//            .expected_nodes = 48,
//        },
//        .{
//            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
//            .depth = 2,
//            .expected_nodes = 2039,
//        },
//        .{
//            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
//            .depth = 3,
//            .expected_nodes = 97862,
//        },
//        .{
//            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
//            .depth = 4,
//            .expected_nodes = 4085603,
//        },
//        .{
//            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
//            .depth = 5,
//            .expected_nodes = 193690690,
//        },
//    };
//
//    var perft = Perft.Perft.init(&b, &attack_table);
//
//    // Run each test position
//    for (test_positions) |test_pos| {
//        try utils.parseFEN(&b, test_pos.fen);
//        const nodes = perft.perftCount(test_pos.depth);
//
//        // Print detailed info for debugging
//        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
//        std.debug.print("Depth: {d}\n", .{test_pos.depth});
//        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
//        std.debug.print("Got nodes: {d}\n", .{nodes});
//
//        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
//    }
//}
//
//test "perft regression test - cpw position" {
//    var b = board.Board.init();
//    var attack_table: attacks.AttackTable = undefined;
//    attack_table.init();
//
//    // Test structure for known positions
//    const PerftTest = struct {
//        fen: []const u8,
//        depth: u32,
//        expected_nodes: u64,
//    };
//
//    // Known good positions and their node counts
//    const test_positions = [_]PerftTest{
//        .{
//            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
//            .depth = 1,
//            .expected_nodes = 6,
//        },
//        .{
//            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
//            .depth = 2,
//            .expected_nodes = 264,
//        },
//        .{
//            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
//            .depth = 3,
//            .expected_nodes = 9467,
//        },
//        .{
//            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
//            .depth = 4,
//            .expected_nodes = 422333,
//        },
//        .{
//            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
//            .depth = 5,
//            .expected_nodes = 15833292,
//        },
//    };
//
//    var perft = Perft.Perft.init(&b, &attack_table);
//
//    // Run each test position
//    for (test_positions) |test_pos| {
//        try utils.parseFEN(&b, test_pos.fen);
//        const nodes = perft.perftCount(test_pos.depth);
//
//        // Print detailed info for debugging
//        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
//        std.debug.print("Depth: {d}\n", .{test_pos.depth});
//        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
//        std.debug.print("Got nodes: {d}\n", .{nodes});
//
//        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
//    }
//}
//
//test "perft regression test - start position" {
//    var b = board.Board.init();
//    var attack_table: attacks.AttackTable = undefined;
//    attack_table.init();
//
//    // Test structure for known positions
//    const PerftTest = struct {
//        fen: []const u8,
//        depth: u32,
//        expected_nodes: u64,
//    };
//
//    // Known good positions and their node counts
//    const test_positions = [_]PerftTest{
//        .{
//            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
//            .depth = 1,
//            .expected_nodes = 20,
//        },
//        .{
//            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
//            .depth = 2,
//            .expected_nodes = 400,
//        },
//        .{
//            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
//            .depth = 3,
//            .expected_nodes = 8902,
//        },
//        .{
//            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
//            .depth = 4,
//            .expected_nodes = 197281,
//        },
//        .{
//            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
//            .depth = 5,
//            .expected_nodes = 4865609,
//        },
//    };
//
//    var perft = Perft.Perft.init(&b, &attack_table);
//
//    // Run each test position
//    for (test_positions) |test_pos| {
//        try utils.parseFEN(&b, test_pos.fen);
//        const nodes = perft.perftCount(test_pos.depth);
//
//        // Print detailed info for debugging
//        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
//        std.debug.print("Depth: {d}\n", .{test_pos.depth});
//        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
//        std.debug.print("Got nodes: {d}\n", .{nodes});
//
//        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
//    }
//}
