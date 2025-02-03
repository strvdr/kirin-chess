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
const uci = @import("uci.zig");
const magics = @import("magics.zig");
const syzygy = @import("syzygy.zig");

const Mode = enum {
    play,
    debug,
    perft,
};

/// For running debug mode, not currently implemented but useful if you want to play
/// around with Kirin!
fn runDebugMode(gameBoard: *board.Board) !void {
    std.debug.print("Debug mode initialized\n", .{});
    utils.printBoard(gameBoard);
    try magics.regenerateAllMagicNumbers();
}

/// This is the fun mode. Running play mode allows you to play against Kirin, whether that be in the terminal,
/// connecting to a GUI, or even running it on Lichess!
fn runPlayMode(gameBoard: *board.Board, attackTable: *attacks.AttackTable) !void {
    try uci.uciLoop(gameBoard, attackTable);
}

/// Perft mode is to evaluate performance. This mode lets us easily run perft tests without messing up
/// any engine functions!
fn runPerftMode(gameBoard: *board.Board, attackTable: *attacks.AttackTable) !void {
    var perft = Perft.Perft.init(gameBoard, attackTable);
    const depth = 6;
    const timer = Perft.Timer.start();
    const nodes = perft.perftCount(depth);
    const elapsed = timer.elapsed();
    std.debug.print("Perft({d}) found {d} nodes in {d}ms\n", .{ depth, nodes, elapsed });
}

pub fn main() !void {
    // Initialize board and attack table
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var opening_book = syzygy.OpeningBook.init(allocator);
    defer opening_book.deinit();

    // Set up initial position
    try utils.parseFEN(&gameBoard, board.Position.start);

    // Parse command line arguments
    var args = std.process.args();
    _ = args.skip(); // Skip program name

    // Default to play mode if no arguments
    var mode: Mode = .play;

    if (args.next()) |arg| {
        mode = if (std.mem.eql(u8, arg, "--debug"))
            .debug
        else if (std.mem.eql(u8, arg, "--perft"))
            .perft
        else if (std.mem.eql(u8, arg, "--play"))
            .play
        else
            .play;
    }

    // Run the appropriate mode
    switch (mode) {
        .play => try runPlayMode(&gameBoard, &attackTable),
        .debug => try runDebugMode(&gameBoard),
        .perft => try runPerftMode(&gameBoard, &attackTable),
    }
}
