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

fn generateMagicNumber() u64 {
    // Using sparse magic numbers (fewer 1 bits) tends to work better
    return getRandomU64() & getRandomU64() & getRandomU64();
}

fn findMagicNumber(square: u6, relevantBits: u5, is_bishop: bool) u64 {
    var occupancies: [4096]u64 = undefined;
    var possibleAttacks: [4096]u64 = undefined;
    var usedAttacks: [4096]u64 = undefined;

    // Get the attack mask for this square
    const attackMask = if (is_bishop)
        attacks.maskBishopAttacks(square)
    else
        attacks.maskRookAttacks(square);

    // Initialize occupancy indices
    const occupancyIndices = @as(u64, 1) << relevantBits;

    // Generate all possible occupancies and their corresponding attacks
    for (0..occupancyIndices) |index| {
        occupancies[index] = utils.setOccupancy(@intCast(index), relevantBits, attackMask);
        possibleAttacks[index] = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancies[index])
        else
            attacks.rookAttacksOTF(square, occupancies[index]);
    }

    // Try to find a magic number
    var tryCount: u32 = 0;
    while (tryCount < MAX_TRIES) : (tryCount += 1) {
        const magicCandidate = generateMagicNumber();

        // Skip if the magic number doesn't have enough high bits set
        if (utils.countBits((attackMask *% magicCandidate) & 0xFF00000000000000) < REQUIRED_HIGH_BITS) {
            continue;
        }

        // Reset the used attacks array
        @memset(&usedAttacks, 0);

        // Test if this magic number works
        var index: u32 = 0;
        var failed = false;
        while (!failed and index < occupancyIndices) : (index += 1) {
            const magicIndex = @as(u12, @intCast((occupancies[index] *% magicCandidate) >>
                @intCast(@as(u8, 64) - relevantBits)));

            // Check for collisions
            if (usedAttacks[magicIndex] == 0) {
                usedAttacks[magicIndex] = possibleAttacks[index];
            } else if (usedAttacks[magicIndex] != possibleAttacks[index]) {
                failed = true;
            }
        }

        if (!failed) {
            std.debug.print("Found magic number for square {d} ({c}{c}) after {d} tries: 0x{x:0>16}\n", .{ square, @as(u8, 'a') + @as(u8, @intCast(square % 8)), @as(u8, '1') + @as(u8, @intCast(square / 8)), tryCount, magicCandidate });
            return magicCandidate;
        }
    }

    @panic("Failed to find magic number");
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

// Verify that a magic number works correctly
fn verifyMagicNumber(square: u6, magic: u64, relevantBits: u5, is_bishop: bool) !void {
    var attackTable: attacks.AttackTable = undefined;
    attackTable.init();

    const mask = if (is_bishop)
        attackTable.bishop_masks[square]
    else
        attackTable.rook_masks[square];

    const maxIndex = @as(u64, 1) << relevantBits;
    var usedIndices = std.AutoHashMap(u12, u64).init(std.heap.page_allocator);
    defer usedIndices.deinit();

    var i: u64 = 0;
    while (i < maxIndex) : (i += 1) {
        const occupancy = utils.setOccupancy(i, relevantBits, mask);
        const magicIndex = @as(u12, @intCast((occupancy *% magic) >> @intCast(64 - relevantBits)));

        const attackPattern = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancy)
        else
            attacks.rookAttacksOTF(square, occupancy);

        if (usedIndices.get(magicIndex)) |previousAttacks| {
            if (previousAttacks != attackPattern) {
                return error.MagicCollision;
            }
        } else {
            try usedIndices.put(magicIndex, attackPattern);
        }
    }
}

test "magic number verification" {
    // Test both bishop and rook magic numbers for a few key squares
    const testSquares = [_]u6{ 0, 27, 63 }; // corners and center

    for (testSquares) |square| {
        try verifyMagicNumber(square, bitboard.Magic.bishopMagicNumbers[square], bitboard.Magic.bishopRelevantBits[square], true);

        try verifyMagicNumber(square, bitboard.Magic.rookMagicNumbers[square], bitboard.Magic.rookRelevantBits[square], false);
    }
}
