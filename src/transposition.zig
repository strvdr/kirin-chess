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
const board = @import("bitboard.zig");
const movegen = @import("movegen.zig");
const Random = std.Random.DefaultPrng;

// Size configuration - adjust based on your needs
pub const TT_SIZE_MB = 64;

// Calculate number of entries and round down to nearest power of 2
pub const TT_ENTRIES = blk: {
    const raw_entries = (TT_SIZE_MB * 1024) / @sizeOf(TTEntry);
    var result: usize = 1;
    while (result * 2 <= raw_entries) : (result *= 2) {}
    break :blk result;
};

// Entry type for the transposition table
pub const TTEntryType = enum(u2) {
    exact, // Exact score
    alpha, // Upper bound
    beta, // Lower bound
};

pub const TTEntry = struct {
    key: u64, // Zobrist hash of the position
    depth: u8, // Search depth
    score: i32, // Evaluation score
    entryType: TTEntryType, // Type of score stored
    bestMove: ?movegen.Move, // Best move found in this position
    age: u8, // Age of the entry for replacement
    is_valid: bool = false, // New field to track validity
};

pub const TranspositionTable = struct {
    // Fixed-size array, no allocation needed
    entries: [TT_ENTRIES]TTEntry align(64) = undefined, // Align to cache line
    age: u8 = 0,

    const Self = @This();

    // Initialize all entries to empty
    pub fn init() Self {
        var table = Self{};
        table.clear();
        return table;
    }

    pub fn probe(self: *const Self, key: u64, ply: u8) ?TTEntry {
        const index = @as(usize, @intCast(key & (TT_ENTRIES - 1)));
        const entry = self.entries[index];

        // First check if the entry is valid and has the correct key
        if (entry.is_valid and entry.key == key) {
            // Readjust mate scores based on current ply
            var adjusted_entry = entry;
            if (entry.score > 48000) {
                adjusted_entry.score -= @as(i32, ply);
            } else if (entry.score < -48000) {
                adjusted_entry.score += @as(i32, ply);
            }
            return adjusted_entry;
        }

        return null;
    }

    pub fn store(self: *Self, key: u64, depth: u8, score: i32, entryType: TTEntryType, bestMove: ?movegen.Move, ply: u8) void {
        const index = @as(usize, @intCast(key & (TT_ENTRIES - 1)));
        const current = &self.entries[index];

        const replace = !current.is_valid or
            current.age != self.age or
            depth >= current.depth or
            entryType == .exact;

        if (replace) {
            // Adjust mate scores to account for distance from root
            const adjusted_score = if (score > 48000)
                score + @as(i32, ply)
            else if (score < -48000)
                score - @as(i32, ply)
            else
                score;

            current.* = .{
                .key = key,
                .depth = depth,
                .score = adjusted_score,
                .entryType = entryType,
                .bestMove = bestMove,
                .age = self.age,
                .is_valid = true,
            };
        }
    }

    pub fn clear(self: *Self) void {
        @memset(&self.entries, TTEntry{
            .key = 0,
            .depth = 0,
            .score = 0,
            .entryType = .exact,
            .bestMove = null,
            .age = 0,
            .is_valid = false,
        });
        self.age = 0;
    }

    pub fn incrementAge(self: *Self) void {
        self.age +%= 1;
    }
};

// Simple compile-time random number generator
fn comptime_random(seed: u64) u64 {
    const result = (seed +% 0x9E3779B97f4A7C15) *% 0x2545F4914F6CDD1D;
    return result ^ (result >> 32);
}

pub const ZobristKeys = struct {
    // Random numbers for pieces [piece_type][square]
    pub const pieces = init: {
        @setEvalBranchQuota(5000); // Ensure enough quota for the nested loop
        var keys: [12][64]u64 = undefined;
        const base_seed: u64 = 0x123456789ABCDEF0;

        var i: usize = 0;
        while (i < 12) : (i += 1) {
            var j: usize = 0;
            while (j < 64) : (j += 1) {
                keys[i][j] = comptime_random(base_seed +% (i * 64 + j));
            }
        }
        break :init keys;
    };

    // Random number for side to move
    pub const side = comptime_random(0xB105F00D);

    // Random numbers for castling rights [4]
    pub const castling = init: {
        var keys: [4]u64 = undefined;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            keys[i] = comptime_random(0xFACADE +% i);
        }
        break :init keys;
    };

    // Random numbers for en passant squares
    pub const enpassant = init: {
        @setEvalBranchQuota(1000); // Ensure enough quota for this loop
        var keys: [64]u64 = undefined;
        var i: usize = 0;
        while (i < 64) : (i += 1) {
            keys[i] = comptime_random(0xDEFACED +% i);
        }
        break :init keys;
    };
};
