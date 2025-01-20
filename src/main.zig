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

pub fn main() !void {
    // Initialize board and attack table
    var gameBoard = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up initial position
    try utils.parseFEN(&gameBoard, board.Position.start);

    // Check args without allocation
    var args = std.process.args();
    _ = args.skip(); // Skip program name

    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--perft")) {
            // Run perft test
            var perft = Perft.Perft.init(&gameBoard, &attackTable);
            const depth = 5;
            const timer = Perft.Timer.start();
            const nodes = perft.perftCount(depth);
            const elapsed = timer.elapsed();
            std.debug.print("Perft({d}) found {d} nodes in {d}ms\n", .{ depth, nodes, elapsed });
            return;
        }
    }

    // Start UCI loop
    try uci.uciLoop(&gameBoard, &attackTable);
}
