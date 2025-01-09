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

fn findMagicNumber(square: u6, relevant_bits: u5, is_bishop: bool) u64 {
    var occupancies: [4096]u64 = undefined;
    var possible_attacks: [4096]u64 = undefined;
    var used_attacks: [4096]u64 = undefined;

    // Get the attack mask for this square
    const attack_mask = if (is_bishop)
        attacks.maskBishopAttacks(square)
    else
        attacks.maskRookAttacks(square);

    // Initialize occupancy indices
    const occupancy_indices = @as(u64, 1) << relevant_bits;

    // Generate all possible occupancies and their corresponding attacks
    for (0..occupancy_indices) |index| {
        occupancies[index] = utils.setOccupancy(@intCast(index), relevant_bits, attack_mask);
        possible_attacks[index] = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancies[index])
        else
            attacks.rookAttacksOTF(square, occupancies[index]);
    }

    // Try to find a magic number
    var try_count: u32 = 0;
    while (try_count < MAX_TRIES) : (try_count += 1) {
        const magic_candidate = generateMagicNumber();

        // Skip if the magic number doesn't have enough high bits set
        if (utils.countBits((attack_mask *% magic_candidate) & 0xFF00000000000000) < REQUIRED_HIGH_BITS) {
            continue;
        }

        // Reset the used attacks array
        @memset(&used_attacks, 0);

        // Test if this magic number works
        var index: u32 = 0;
        var failed = false;
        while (!failed and index < occupancy_indices) : (index += 1) {
            const magic_index = @as(u12, @intCast((occupancies[index] *% magic_candidate) >>
                @intCast(@as(u8, 64) - relevant_bits)));

            // Check for collisions
            if (used_attacks[magic_index] == 0) {
                used_attacks[magic_index] = possible_attacks[index];
            } else if (used_attacks[magic_index] != possible_attacks[index]) {
                failed = true;
            }
        }

        if (!failed) {
            std.debug.print("Found magic number for square {d} ({c}{c}) after {d} tries: 0x{x:0>16}\n", .{ square, @as(u8, 'a') + @as(u8, @intCast(square % 8)), @as(u8, '1') + @as(u8, @intCast(square / 8)), try_count, magic_candidate });
            return magic_candidate;
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
fn verifyMagicNumber(square: u6, magic: u64, relevant_bits: u5, is_bishop: bool) !void {
    var attack_table: attacks.AttackTable = undefined;
    attack_table.init();

    const mask = if (is_bishop)
        attack_table.bishop_masks[square]
    else
        attack_table.rook_masks[square];

    const max_index = @as(u64, 1) << relevant_bits;
    var used_indices = std.AutoHashMap(u12, u64).init(std.heap.page_allocator);
    defer used_indices.deinit();

    var i: u64 = 0;
    while (i < max_index) : (i += 1) {
        const occupancy = utils.setOccupancy(i, relevant_bits, mask);
        const magic_index = @as(u12, @intCast((occupancy *% magic) >> @intCast(64 - relevant_bits)));

        const attack_pattern = if (is_bishop)
            attacks.bishopAttacksOTF(square, occupancy)
        else
            attacks.rookAttacksOTF(square, occupancy);

        if (used_indices.get(magic_index)) |previous_attacks| {
            if (previous_attacks != attack_pattern) {
                return error.MagicCollision;
            }
        } else {
            try used_indices.put(magic_index, attack_pattern);
        }
    }
}

test "magic number verification" {
    // Test both bishop and rook magic numbers for a few key squares
    const test_squares = [_]u6{ 0, 27, 63 }; // corners and center

    for (test_squares) |square| {
        try verifyMagicNumber(square, bitboard.Magic.bishopMagicNumbers[square], bitboard.Magic.bishopRelevantBits[square], true);

        try verifyMagicNumber(square, bitboard.Magic.rookMagicNumbers[square], bitboard.Magic.rookRelevantBits[square], false);
    }
}
