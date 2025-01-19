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

pub fn main() !void {
    //const testa = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - ";
    var b = board.Board.init();
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    // Set up position
    try utils.parseFEN(&b, board.Position.kiwiPete);

    var perft = Perft.Perft.init(&b, &attackTable);
    perft.debugMoveGeneration();

    const depth = 5;
    // Run perft test
    const timer = Perft.Timer.start();
    const nodes = perft.perftCount(depth);
    const elapsed = timer.elapsed();

    std.debug.print("Perft({d}) found {d} nodes in {d}ms\n", .{ depth, nodes, elapsed });
}
