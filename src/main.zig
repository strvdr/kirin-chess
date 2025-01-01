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

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    attacks.initLeaperAttacks();
    //std.debug.print("Rand Num: {d}\n", .{});
    magic.initMagicNumbers();
    // const bitsInMask = utils.countBits(attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));
    // std.debug.print("Bits in mask: {d}\n", .{bitsInMask});
    // const occupancy = utils.setOccupancy(4095, bitsInMask, attacks.maskRookAttacks(@intFromEnum(bitboard.boardSquares.a1)));

    try bw.flush(); // Don't forget to flush!
}
