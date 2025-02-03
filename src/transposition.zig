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

const Random = std.Random.DefaultPrng;
const std = @import("std");
const board = @import("bitboard.zig");
const movegen = @import("movegen.zig");

pub const TT_SIZE_MB = 512;

// Calculate number of entries and round down to nearest power of 2
pub const TT_ENTRIES = blk: {
    const bytes_per_entry = @sizeOf(TTEntry);
    const total_bytes = TT_SIZE_MB * 1024;
    const raw_entries = total_bytes / bytes_per_entry;
    var result: usize = 1;
    while (result * 2 <= raw_entries) : (result *= 2) {}
    break :blk result;
};

pub const TTEntryType = enum(u2) {
    exact, // Exact score
    alpha, // Upper bound
    beta, // Lower bound
};

pub const TTEntry = struct {
    key: u64,
    depth: i8,
    score: i32,
    entryType: TTEntryType,
    bestMove: ?movegen.Move,
    age: u8,
    generation: u8,
    is_valid: bool,

    pub fn init() TTEntry {
        return .{
            .key = 0,
            .depth = 0,
            .score = 0,
            .entryType = .exact,
            .bestMove = null,
            .age = 0,
            .generation = 0,
            .is_valid = false,
        };
    }
};

pub const TranspositionTable = struct {
    entries: [TT_ENTRIES]TTEntry align(64),
    generation: u8,
    age: u8, // Added back the age field

    pub fn init() TranspositionTable {
        return .{
            .entries = [_]TTEntry{TTEntry.init()} ** TT_ENTRIES,
            .generation = 1,
            .age = 0,
        };
    }

    pub fn probe(self: *const TranspositionTable, key: u64, ply: u8, alpha: i32, beta: i32, depth: i8) ?TTEntry {
        const index = @as(usize, @intCast(key & (TT_ENTRIES - 1)));
        const entry = self.entries[index];

        if (!entry.is_valid or entry.key != key) {
            return null;
        }

        // Only use entries that are deep enough
        if (entry.depth >= depth) {
            var score = entry.score;

            // Adjust mate scores relative to current ply
            if (score > 48000) {
                score -= @as(i32, ply);
            } else if (score < -48000) {
                score += @as(i32, ply);
            }

            // Return based on entry type and bounds
            switch (entry.entryType) {
                .exact => return entry,
                .alpha => if (score <= alpha) return entry,
                .beta => if (score >= beta) return entry,
            }
        }

        // Return the entry for move ordering even if we can't use the score
        return entry;
    }

    pub fn store(self: *TranspositionTable, key: u64, depth: i8, score: i32, entryType: TTEntryType, bestMove: ?movegen.Move, ply: u8) void {
        const index = @as(usize, @intCast(key & (TT_ENTRIES - 1)));
        const current = &self.entries[index];

        // More sophisticated replacement strategy
        const should_replace = !current.is_valid or
            current.generation != self.generation or
            depth >= current.depth - 2 or // Allow replacing slightly shallower entries
            (depth == current.depth and entryType == .exact) or
            (current.age < self.age and depth + 3 >= current.depth); // Age-based replacement

        if (should_replace) {
            // Adjust mate scores to be relative to root
            var adjusted_score = score;
            if (score > 48000) {
                adjusted_score += @as(i32, ply);
            } else if (score < -48000) {
                adjusted_score -= @as(i32, ply);
            }

            current.* = .{
                .key = key,
                .depth = depth,
                .score = adjusted_score,
                .entryType = entryType,
                .bestMove = bestMove,
                .age = self.age,
                .generation = self.generation,
                .is_valid = true,
            };
        } else if (bestMove != null and current.bestMove == null) {
            // Always store a new best move even if we don't replace the entry
            current.bestMove = bestMove;
        }
    }

    pub fn clear(self: *TranspositionTable) void {
        for (&self.entries) |*entry| {
            entry.* = TTEntry.init();
        }
        self.generation = 1;
        self.age = 0;
    }

    pub fn newSearch(self: *TranspositionTable) void {
        self.generation +%= 1;
        if (self.generation == 0) self.generation = 1;
    }

    pub fn incrementAge(self: *TranspositionTable) void {
        self.age +%= 1;
    }
};

// Simple compile-time random number generator
fn comptime_random(seed: u64) u64 {
    var x = seed;
    x ^= (x << 13) & 0xFFFFFFFFFFFFFFFF;
    x ^= (x >> 7) & 0xFFFFFFFFFFFFFFFF;
    x ^= (x << 17) & 0xFFFFFFFFFFFFFFFF;
    return x;
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
