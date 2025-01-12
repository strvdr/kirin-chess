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

//I think the issue is that we currently store the board state, see if the king is put in check when we make a move,
pub fn main() !void {
    //const kiwiPeteMod = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/p1N2Q1p/P1PBBPPP/R3K2R w KQkq - 0 1 ";
    var b = board.Board.init();
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    // Set up position
    try utils.parseFEN(&b, board.Position.kiwiPete);

    var perft = Perft.Perft.init(&b, &attack_table);
    perft.debugMoveGeneration();

    // Run perft test
    const timer = Perft.Timer.start();
    const nodes = perft.perftCount(2);
    const elapsed = timer.elapsed();

    std.debug.print("Perft(2) found {d} nodes in {d}ms\n", .{ nodes, elapsed });
}
