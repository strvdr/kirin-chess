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

// Constants for magic finding
const MAX_TRIES = 100_000_000;
const REQUIRED_HIGH_BITS = 6;
const RANDOM_SEED = 1804289383;

// Better random number generation
var state: u64 = RANDOM_SEED;

fn getRandomU32() u32 {
    var x = @as(u32, @intCast(state));
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    state = x;
    return x;
}

fn getRandomU64() u64 {
    // Using more bits from each u32 for better distribution
    const n1: u64 = @as(u64, getRandomU32());
    const n2: u64 = @as(u64, getRandomU32());
    return (n1 & 0xFFFFFFFF) | ((n2 & 0xFFFFFFFF) << 32);
}

fn findMagicNumber(square: u6, relevantBits: u5, is_bishop: bool) u64 {
    var occupancies: [4096]u64 = undefined;
    var attackTable: [4096]u64 = undefined;
    var used: [4096]u64 = undefined;

    // Get attack mask for this square
    const attackMask = if (is_bishop)
        attacks.maskBishopAttacks(square)
    else
        attacks.maskRookAttacks(square);

    // Initialize occupancy indices
    const occupancyIndices = @as(u64, 1) << relevantBits;

    // Generate all possible occupancies and their corresponding attacks
    for (0..occupancyIndices) |index| {
        occupancies[index] = utils.setOccupancy(@intCast(index), relevantBits, attackMask);
        attackTable[index] = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancies[index])
        else
            attacks.rookAttacksOTF(square, occupancies[index]);
    }

    // Try magic numbers until one works
    var tries: u32 = 0;
    while (tries < MAX_TRIES) : (tries += 1) {
        // Generate a candidate magic number
        const magic = generateMagicNumber();

        // Skip if the magic number doesn't have enough leading zeros after multiplication
        if (utils.countBits((attackMask *% magic) & 0xFF00000000000000) < 6) {
            continue;
        }

        // Reset used attacks array
        @memset(&used, 0);
        var fail = false;

        // Test this magic number against all occupancies
        var i: usize = 0;
        while (i < occupancyIndices and !fail) : (i += 1) {
            const magicIndex = @as(u12, @intCast((occupancies[i] *% magic) >>
                @intCast(@as(u8, 64) - relevantBits)));

            if (used[magicIndex] == 0) {
                used[magicIndex] = attackTable[i];
            } else if (used[magicIndex] != attackTable[i]) {
                fail = true;
            }
        }

        if (!fail) {
            return magic;
        }
    }

    @panic("Failed to find magic number");
}

fn generateMagicNumber() u64 {
    return getRandomU64() &
        getRandomU64() &
        getRandomU64();
}

fn verifyMagicNumber(square: u6, magic: u64, relevantBits: u5, is_bishop: bool) !void {
    var used = std.AutoHashMap(u12, u64).init(std.heap.page_allocator);
    defer used.deinit();

    const mask = if (is_bishop)
        attacks.maskBishopAttacks(square)
    else
        attacks.maskRookAttacks(square);

    const occupancyIndices = @as(u64, 1) << relevantBits;

    var index: usize = 0;
    while (index < occupancyIndices) : (index += 1) {
        const occupancy = utils.setOccupancy(@intCast(index), relevantBits, mask);
        const magicIndex = @as(u12, @intCast((occupancy *% magic) >>
            @intCast(@as(u8, 64) - relevantBits)));

        const attackTable = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancy)
        else
            attacks.rookAttacksOTF(square, occupancy);

        if (used.get(magicIndex)) |existing| {
            if (existing != attackTable) {
                return error.MagicCollision;
            }
        } else {
            try used.put(magicIndex, attackTable);
        }
    }
}

test "verify all magic numbers" {
    // Test both bishop and rook magic numbers for all squares
    for (0..64) |square| {
        const sq: u6 = @intCast(square);

        // Verify bishop magic number
        try verifyMagicNumber(sq, bitboard.Magic.bishopMagicNumbers[sq], bitboard.Magic.bishopRelevantBits[sq], true);

        // Verify rook magic number
        try verifyMagicNumber(sq, bitboard.Magic.rookMagicNumbers[sq], bitboard.Magic.rookRelevantBits[sq], false);
    }
}

pub fn generateAllMagicNumbers() !void {
    // Open a file for writing
    const file = try std.fs.cwd().createFile(
        "generated_magics.txt",
        .{ .read = true },
    );
    defer file.close();

    const writer = file.writer();

    try writer.writeAll("// Generated Bishop Magic Numbers\n");
    try writer.writeAll("pub const bishopMagicNumbers = [64]u64{\n");
    for (0..64) |square| {
        const result = findMagicNumber(@intCast(square), bitboard.Magic.bishopRelevantBits[square], true);
        try writer.print("    0x{x:0>16},  // {d}\n", .{ result, square });
    }
    try writer.writeAll("};\n\n");

    try writer.writeAll("// Generated Rook Magic Numbers\n");
    try writer.writeAll("pub const rookMagicNumbers = [64]u64{\n");
    for (0..64) |square| {
        const result = findMagicNumber(@intCast(square), bitboard.Magic.rookRelevantBits[square], false);
        try writer.print("    0x{x:0>16},  // {d}\n", .{ result, square });
    }
    try writer.writeAll("};\n");
}

pub fn main() !void {
    std.debug.print("Generating magic numbers...\n", .{});
    try generateAllMagicNumbers();
    std.debug.print("Magic numbers have been generated and saved to 'generated_magics.txt'\n", .{});
}

pub fn regenerateAllMagicNumbers() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("Generating bishop magic numbers...\n");
    for (0..64) |sq| {
        const square = @as(u6, @intCast(sq));
        const magic = findMagicNumber(square, bitboard.Magic.bishopRelevantBits[square], true);
        try stdout.print("Bishop square {d}: 0x{x:0>16}\n", .{ square, magic });

        // Verify the generated number
        try verifyMagicNumber(square, magic, bitboard.Magic.bishopRelevantBits[square], true);
    }

    try stdout.writeAll("\nGenerating rook magic numbers...\n");
    for (0..64) |sq| {
        const square = @as(u6, @intCast(sq));
        const magic = findMagicNumber(square, bitboard.Magic.rookRelevantBits[square], false);
        try stdout.print("Rook square {d}: 0x{x:0>16}\n", .{ square, magic });

        // Verify the generated number
        try verifyMagicNumber(square, magic, bitboard.Magic.rookRelevantBits[square], false);
    }
}
