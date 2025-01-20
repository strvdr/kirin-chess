const std = @import("std");
const board = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");
const utils = @import("utils.zig");
const Perft = @import("perft.zig");
const magic = @import("magics.zig");

test "perft regression test - kiwipete position" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Test structure for known positions
    const PerftTest = struct {
        fen: []const u8,
        depth: u32,
        expected_nodes: u64,
    };

    // Known good positions and their node counts
    const test_positions = [_]PerftTest{
        .{
            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            .depth = 1,
            .expected_nodes = 48,
        },
        .{
            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            .depth = 2,
            .expected_nodes = 2039,
        },
        .{
            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            .depth = 3,
            .expected_nodes = 97862,
        },
        .{
            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            .depth = 4,
            .expected_nodes = 4085603,
        },
        .{
            .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            .depth = 5,
            .expected_nodes = 193690690,
        },
    };

    var perft = Perft.Perft.init(&b, &attack_table);

    // Run each test position
    for (test_positions) |test_pos| {
        try utils.parseFEN(&b, test_pos.fen);
        const nodes = perft.perftCount(test_pos.depth);

        // Print detailed info for debugging
        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
        std.debug.print("Depth: {d}\n", .{test_pos.depth});
        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
        std.debug.print("Got nodes: {d}\n", .{nodes});

        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
    }
}

test "perft regression test - cpw position" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Test structure for known positions
    const PerftTest = struct {
        fen: []const u8,
        depth: u32,
        expected_nodes: u64,
    };

    // Known good positions and their node counts
    const test_positions = [_]PerftTest{
        .{
            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            .depth = 1,
            .expected_nodes = 6,
        },
        .{
            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            .depth = 2,
            .expected_nodes = 264,
        },
        .{
            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            .depth = 3,
            .expected_nodes = 9467,
        },
        .{
            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            .depth = 4,
            .expected_nodes = 422333,
        },
        .{
            .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            .depth = 5,
            .expected_nodes = 15833292,
        },
    };

    var perft = Perft.Perft.init(&b, &attack_table);

    // Run each test position
    for (test_positions) |test_pos| {
        try utils.parseFEN(&b, test_pos.fen);
        const nodes = perft.perftCount(test_pos.depth);

        // Print detailed info for debugging
        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
        std.debug.print("Depth: {d}\n", .{test_pos.depth});
        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
        std.debug.print("Got nodes: {d}\n", .{nodes});

        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
    }
}

test "perft regression test - start position" {
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Test structure for known positions
    const PerftTest = struct {
        fen: []const u8,
        depth: u32,
        expected_nodes: u64,
    };

    // Known good positions and their node counts
    const test_positions = [_]PerftTest{
        .{
            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            .depth = 1,
            .expected_nodes = 20,
        },
        .{
            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            .depth = 2,
            .expected_nodes = 400,
        },
        .{
            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            .depth = 3,
            .expected_nodes = 8902,
        },
        .{
            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            .depth = 4,
            .expected_nodes = 197281,
        },
        .{
            .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            .depth = 5,
            .expected_nodes = 4865609,
        },
    };

    var perft = Perft.Perft.init(&b, &attack_table);

    // Run each test position
    for (test_positions) |test_pos| {
        try utils.parseFEN(&b, test_pos.fen);
        const nodes = perft.perftCount(test_pos.depth);

        // Print detailed info for debugging
        std.debug.print("\nTesting position: {s}\n", .{test_pos.fen});
        std.debug.print("Depth: {d}\n", .{test_pos.depth});
        std.debug.print("Expected nodes: {d}\n", .{test_pos.expected_nodes});
        std.debug.print("Got nodes: {d}\n", .{nodes});

        try std.testing.expectEqual(test_pos.expected_nodes, nodes);
    }
}
