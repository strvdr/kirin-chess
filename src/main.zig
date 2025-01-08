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
const utils = @import("utils.zig");
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const magic = @import("magics.zig");
const movegen = @import("movegen.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    attacks.initAll();
    utils.parseFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/Pp2P3/2N2Q1p/1PPBBPPP/R3K2R b KQkq - 0 1 ");
    utils.printBoard();
    const move: u32 = movegen.encodeMove(@intFromEnum(bitboard.boardSquares.a7), @intFromEnum(bitboard.boardSquares.a5), @intFromEnum(bitboard.pieceEncoding.p), 1, 1, 0, 0, 0);

    const sourceSquare: u32 = movegen.decodeMoveSource(move);
    const targetSquare: u32 = movegen.decodeMoveTarget(move);
    const piece: u32 = movegen.decodeMovePiece(move);
    const promoted: u32 = movegen.decodeMovePromoted(move);
    const capture: u32 = movegen.decodeMoveCapture(move);

    std.debug.print("source square: {s}\n", .{bitboard.squareCoordinates[sourceSquare]});
    std.debug.print("target square: {s}\n", .{bitboard.squareCoordinates[targetSquare]});
    std.debug.print("piece: {s}\n", .{bitboard.unicodePieces[piece]});
    std.debug.print("promoted: {s}\n", .{if (promoted == 1) "yes" else "no"});
    std.debug.print("capture: {s}\n", .{if (capture == 1) "yes" else "no"});
    //movegen.generateMoves();
    try bw.flush(); // Don't forget to flush!
}
