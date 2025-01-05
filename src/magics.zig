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
const bitboard = @import("bitboard.zig");
const attacks = @import("attacks.zig");
const utils = @import("utils.zig");

fn getRandomNumberU32() u32 {
    var number: u32 = @intCast(bitboard.state);

    number ^= number << 13;
    number ^= number >> 17;
    number ^= number << 5;

    bitboard.state = number;

    return number;
}

//from Tord Ramstad's Article on Generating Magic Numbers
fn getRandomNumberU64() u64 {
    const n1: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n2: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n3: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n4: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;

    return n1 | (n2 << 16) | (n3 << 32) | (n4 << 48);
}

fn generateMagicNumber() u64 {
    return getRandomNumberU64() & getRandomNumberU64() & getRandomNumberU64();
}

fn findMagicNumber(square: u6, relevantBits: u5, bishop: bool) u64 {
    var occupancies: [4096]u64 = undefined;
    var unusedAttacks: [4096]u64 = undefined;
    var usedAttacks: [4096]u64 = undefined;
    var attackMask: u64 = undefined;

    if (bishop) {
        attackMask = attacks.maskBishopAttacks(square);
    } else {
        attackMask = attacks.maskRookAttacks(square);
    }

    const occupancyIndicies: u64 = @as(u64, 1) << relevantBits;

    for (0..occupancyIndicies) |index| {
        occupancies[index] = utils.setOccupancy(@intCast(index), relevantBits, attackMask);
        if (bishop) {
            unusedAttacks[index] = attacks.bishopAttacksOTF(square, occupancies[index]);
        } else {
            unusedAttacks[index] = attacks.rookAttacksOTF(square, occupancies[index]);
        }
    }

    var randCount: u32 = 0;
    while (randCount < 100000000) : (randCount += 1) {
        const magicNumber = generateMagicNumber();

        if (utils.countBits((attackMask *% magicNumber) & 0xFF00000000000000) < 6) continue;

        @memset(usedAttacks[0..], 0);
        var index: u32 = 0;
        var fail: bool = false;

        while (!fail and index < occupancyIndicies) {
            const magicIndex: u64 = @intCast((occupancies[index] *% magicNumber) >> @intCast(64 - @as(u8, relevantBits)));

            if (usedAttacks[magicIndex] == 0) {
                usedAttacks[magicIndex] = unusedAttacks[index];
            } else if (usedAttacks[magicIndex] != unusedAttacks[index]) {
                fail = true;
            }
            index += 1;
        }
        if (!fail) return magicNumber;
    }

    std.debug.print("   Magic Number Fails!", .{});
    return 0;
}

fn initMagicNumbers() void {
    std.debug.print("bishop:\n", .{});
    for (0..64) |square| {
        const result: u64 = findMagicNumber(@intCast(square), bitboard.bishopRelevantBits[square], true);
        std.debug.print("0x{x},\n", .{result});
    }
    std.debug.print("rook:\n", .{});
    for (0..64) |square| {
        const result: u64 = findMagicNumber(@intCast(square), bitboard.rookRelevantBits[square], false);
        std.debug.print(" 0x{x},\n", .{result});
    }
}
