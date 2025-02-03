// setoption name BookFile value opening_book.bin
const std = @import("std");
const board = @import("bitboard.zig");
const movegen = @import("movegen.zig");
const utils = @import("utils.zig");
const transposition = @import("transposition.zig");

pub const OpeningBookError = error{
    FileNotFound,
    InvalidFormat,
    ReadError,
    HashNotFound,
    InvalidMove,
    InvalidBookEntry,
};

const BookEntry = extern struct {
    hash: u64,
    source: u8,
    target: u8,
    promotion: u8,
    moveType: u8,
    piece: u8,
    weight: u16,
    learn: u16,
    //padding: [7]u8 = undefined, // Ensure 32-byte alignment

    pub fn debugPrint(self: *const @This()) void {
        std.debug.print(
            \\BookEntry{{
            \\  hash: 0x{x:0>16},
            \\  source: {d},
            \\  target: {d},
            \\  promotion: {d},
            \\  moveType: {d},
            \\  piece: {d},
            \\  weight: {d},
            \\  learn: {d}
            \\}}
            \\
        , .{
            self.hash,
            self.source,
            self.target,
            self.promotion,
            self.moveType,
            self.piece,
            self.weight,
            self.learn,
        });
    }
};

comptime {
    std.debug.assert(@sizeOf(BookEntry) == 24);
}

pub const OpeningBook = struct {
    entries: std.AutoHashMap(u64, []BookEntry),
    allocator: std.mem.Allocator,
    is_loaded: bool = false,

    pub fn init(allocator: std.mem.Allocator) OpeningBook {
        return .{
            .entries = std.AutoHashMap(u64, []BookEntry).init(allocator),
            .allocator = allocator,
            .is_loaded = false,
        };
    }

    pub fn deinit(self: *OpeningBook) void {
        var iter = self.entries.valueIterator();
        while (iter.next()) |entries| {
            self.allocator.free(entries.*);
        }
        self.entries.deinit();
    }

    pub fn loadFromFile(self: *OpeningBook, filename: []const u8) !void {
        std.debug.print("Verifying Zobrist keys match Python implementation...\n", .{});
        verifyZobristKeys();

        // Clear existing entries if any
        if (self.is_loaded) {
            self.deinit();
            self.entries = std.AutoHashMap(u64, []BookEntry).init(self.allocator);
        }

        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        const stat = try file.stat();
        std.debug.print("Book file size: {d} bytes\n", .{stat.size});

        if (stat.size < @sizeOf(BookEntry)) {
            std.debug.print("File too small!\n", .{});
            return error.InvalidFormat;
        }

        // Verify entry alignment
        if ((stat.size - 12) % @sizeOf(BookEntry) != 0) {
            std.debug.print("File size not aligned with entry size!\n", .{});
            return error.InvalidFormat;
        }

        const reader = file.reader();

        // Read and verify magic number and version
        const magic = try reader.readInt(u64, .big);
        const version = try reader.readInt(u32, .little);

        std.debug.print("Magic number read: 0x{x:0>16}\n", .{magic});
        std.debug.print("Version read: {d}\n", .{version});

        if (magic != 0x72626f6f6b696e67) {
            std.debug.print("Magic number mismatch! Got 0x{x:0>16}, expected 0x72626f6f6b696e67\n", .{magic});
            return OpeningBookError.InvalidFormat;
        }

        if (version != 1) {
            std.debug.print("Version mismatch! Got {d}, expected 1\n", .{version});
            return OpeningBookError.InvalidFormat;
        }

        const entry_size = @sizeOf(BookEntry);
        const remaining_size = stat.size - 12;

        std.debug.print("Entry size: {d} bytes\n", .{entry_size});
        std.debug.print("Remaining size: {d} bytes\n", .{remaining_size});
        std.debug.print("Remainder when divided by entry size: {d}\n", .{remaining_size % entry_size});

        if (remaining_size % entry_size != 0) {
            std.debug.print("File size not aligned with entry size\n", .{});
            return OpeningBookError.InvalidFormat;
        }

        const expected_entries = @divExact(remaining_size, entry_size);
        std.debug.print("Expected number of entries: {d}\n", .{expected_entries});
        std.debug.print("Current file position: {d}\n", .{try file.getPos()});

        var buffer: [@sizeOf(BookEntry)]u8 = undefined;
        var total_entries: usize = 0;

        while (true) {
            // Progress logging every 1000 entries
            if (total_entries % 1000 == 0) {
                std.debug.print("Reading entry {d} of {d}...\n", .{ total_entries, expected_entries });
            }

            // Read the next entry
            const bytes_read = try reader.readAll(&buffer);
            if (bytes_read == 0) {
                // Check if we've read all expected entries
                if (total_entries == expected_entries) {
                    break;
                } else {
                    std.debug.print("Unexpected end of file at entry {d}\n", .{total_entries});
                    return error.ReadError;
                }
            }

            if (bytes_read != entry_size) {
                std.debug.print("Incomplete read: got {d} bytes, expected {d}\n", .{ bytes_read, entry_size });
                return error.ReadError;
            }

            // Parse the entry
            const entry = @as(*align(1) const BookEntry, @ptrCast(&buffer)).*;

            // Validate the entry
            if (entry.source >= 64 or entry.target >= 64) {
                std.debug.print("Invalid entry at position {d}: source={d}, target={d}\n", .{ total_entries, entry.source, entry.target });
                return OpeningBookError.InvalidFormat;
            }

            // Print first few entries for debugging
            if (total_entries < 3) {
                std.debug.print("\nEntry {d}:\n", .{total_entries});
                entry.debugPrint();
            }

            // Store the entry
            const gop = try self.entries.getOrPut(entry.hash);
            if (!gop.found_existing) {
                var new_entries = try self.allocator.alloc(BookEntry, 1);
                new_entries[0] = entry;
                gop.value_ptr.* = new_entries;
            } else {
                const new_entries = try self.allocator.realloc(gop.value_ptr.*, gop.value_ptr.*.len + 1);
                new_entries[new_entries.len - 1] = entry;
                gop.value_ptr.* = new_entries;
            }

            total_entries += 1;
        }

        std.debug.print("Successfully loaded {d} entries from book\n", .{total_entries});
        self.is_loaded = true;
    }

    pub fn getBookMove(self: *const OpeningBook, gameBoard: *const board.Board) !?movegen.Move {
        if (!self.is_loaded) {
            std.debug.print("Book not loaded!\n", .{});
            return null;
        }

        const pos_hash = generatePositionHash(gameBoard);
        std.debug.print("\nLooking up position hash: 0x{x:0>16}\n", .{pos_hash});

        // Print out first few entries in our hash map for debugging
        var iter = self.entries.iterator();
        var count: usize = 0;
        while (iter.next()) |entry| : (count += 1) {
            if (count < 5) {
                std.debug.print("Book contains hash: 0x{x:0>16} with {d} moves\n", .{ entry.key_ptr.*, entry.value_ptr.*.len });
            }
        }
        std.debug.print("Total unique positions in book: {d}\n", .{self.entries.count()});

        if (self.entries.get(pos_hash)) |entries| {
            std.debug.print("Found {d} book moves for position\n", .{entries.len});
            var valid_entries = std.ArrayList(BookEntry).init(self.allocator);
            defer valid_entries.deinit();

            for (entries) |entry| {
                std.debug.print("Validating move: source={d} target={d} piece={d}\n", .{ entry.source, entry.target, entry.piece });

                if (validateBookEntry(entry, gameBoard)) {
                    try valid_entries.append(entry);
                    std.debug.print("Move is valid\n", .{});
                } else {
                    std.debug.print("Move validation failed\n", .{});
                }
            }

            if (valid_entries.items.len == 0) {
                std.debug.print("No valid moves found\n", .{});
                return null;
            }

            // Calculate total weight and print weights
            var total_weight: u32 = 0;
            for (valid_entries.items) |entry| {
                total_weight += entry.weight;
                std.debug.print("Move weight: {d}\n", .{entry.weight});
            }
            std.debug.print("Total weight: {d}\n", .{total_weight});

            if (total_weight == 0) return null;

            // Select random move
            const rnd = std.crypto.random.int(u32) % total_weight;
            std.debug.print("Random number: {d}\n", .{rnd});

            var running_total: u32 = 0;
            for (valid_entries.items) |entry| {
                running_total += entry.weight;
                if (running_total > rnd) {
                    const move = try entryToMove(entry, gameBoard);
                    std.debug.print("Selected book move: ", .{});
                    try printBookMove(move);
                    return move;
                }
            }
        } else {
            std.debug.print("No book entries found for position\n", .{});
        }

        return null;
    }

    fn printBookMove(move: movegen.Move) !void {
        const sourceCoords = try move.source.toCoordinates();
        const targetCoords = try move.target.toCoordinates();
        std.debug.print("{c}{c}{c}{c}", .{
            sourceCoords[0], sourceCoords[1],
            targetCoords[0], targetCoords[1],
        });
        if (move.moveType == .promotion or move.moveType == .promotionCapture) {
            var promotion_piece: board.Piece = undefined;
            switch (move.promotionPiece) {
                .queen => promotion_piece = if (move.piece.isWhite()) .Q else .q,
                .rook => promotion_piece = if (move.piece.isWhite()) .R else .r,
                .bishop => promotion_piece = if (move.piece.isWhite()) .B else .b,
                .knight => promotion_piece = if (move.piece.isWhite()) .N else .n,
                .none => {},
            }
            std.debug.print("{c}", .{promotion_piece.toPromotionChar()});
        }
        std.debug.print("\n", .{});
    }

    pub fn verifyZobristKeys() void {
        // Print first few piece keys to compare with Python
        for (0..3) |piece| {
            for (0..3) |square| {
                std.debug.print("Zobrist key for piece={d} square={d}: 0x{x:0>16}\n", .{ piece, square, transposition.ZobristKeys.pieces[piece][square] });
            }
        }

        // Print castling keys
        for (transposition.ZobristKeys.castling, 0..) |key, i| {
            std.debug.print("Castling key {d}: 0x{x:0>16}\n", .{ i, key });
        }

        // Print side to move key
        std.debug.print("Side to move key: 0x{x:0>16}\n", .{transposition.ZobristKeys.side});
    }

    fn generatePositionHash(gameBoard: *const board.Board) u64 {
        var hash: u64 = 0;

        // Add better debugging
        std.debug.print("Starting position hash calculation...\n", .{});

        // Hash pieces
        inline for (gameBoard.bitboard, 0..) |bitboard, piece_idx| {
            var pieces = bitboard;
            while (pieces != 0) {
                const square = utils.getLSBindex(pieces);
                if (square >= 0) {
                    const piece_hash = transposition.ZobristKeys.pieces[piece_idx][@intCast(square)];
                    hash ^= piece_hash;
                    std.debug.print("Hashing piece {d} on square {d}: ^= 0x{x:0>16}\n", .{ piece_idx, square, piece_hash });
                }
                pieces &= pieces - 1;
            }
        }

        // Hash castling rights with debug prints
        if (gameBoard.castling.whiteKingside) {
            const castle_hash = transposition.ZobristKeys.castling[0];
            hash ^= castle_hash;
            std.debug.print("Hashing WK castling: ^= 0x{x:0>16}\n", .{castle_hash});
        }
        if (gameBoard.castling.whiteQueenside) {
            const castle_hash = transposition.ZobristKeys.castling[1];
            hash ^= castle_hash;
            std.debug.print("Hashing WQ castling: ^= 0x{x:0>16}\n", .{castle_hash});
        }
        if (gameBoard.castling.blackKingside) {
            const castle_hash = transposition.ZobristKeys.castling[2];
            hash ^= castle_hash;
            std.debug.print("Hashing BK castling: ^= 0x{x:0>16}\n", .{castle_hash});
        }
        if (gameBoard.castling.blackQueenside) {
            const castle_hash = transposition.ZobristKeys.castling[3];
            hash ^= castle_hash;
            std.debug.print("Hashing BQ castling: ^= 0x{x:0>16}\n", .{castle_hash});
        }

        // Hash side to move
        if (gameBoard.sideToMove == .black) {
            const side_hash = transposition.ZobristKeys.side;
            hash ^= side_hash;
            std.debug.print("Hashing black to move: ^= 0x{x:0>16}\n", .{side_hash});
        }

        std.debug.print("Final position hash: 0x{x:0>16}\n", .{hash});
        return hash;
    }
};

fn validateBookEntry(entry: BookEntry, gameBoard: *const board.Board) bool {
    std.debug.print("Validating entry:\n", .{});
    std.debug.print("  Source: {d}\n", .{entry.source});
    std.debug.print("  Target: {d}\n", .{entry.target});
    std.debug.print("  Piece: {d}\n", .{entry.piece});
    std.debug.print("  Move type: {d}\n", .{entry.moveType});

    // Validate square indices
    if (entry.source >= 64 or entry.target >= 64) {
        std.debug.print("  Invalid squares\n", .{});
        return false;
    }

    // Validate move type
    if (entry.moveType > 6) {
        std.debug.print("  Invalid move type\n", .{});
        return false;
    }

    // Validate piece type
    if (entry.piece >= 12) {
        std.debug.print("  Invalid piece type\n", .{});
        return false;
    }

    // Verify piece exists at source square
    const piece_bb = gameBoard.bitboard[entry.piece];
    if (utils.getBit(piece_bb, @as(u6, @intCast(entry.source))) == 0) {
        std.debug.print("  Piece not found at source square\n", .{});
        return false;
    }

    // Print the actual piece found at the source square
    for (gameBoard.bitboard, 0..) |bb, i| {
        if (utils.getBit(bb, @as(u6, @intCast(entry.source))) != 0) {
            std.debug.print("  Found piece type {d} at source\n", .{i});
        }
    }

    std.debug.print("  Move appears valid\n", .{});
    return true;
}

fn entryToMove(entry: BookEntry, gameBoard: *const board.Board) !movegen.Move {
    if (!validateBookEntry(entry, gameBoard)) {
        return OpeningBookError.InvalidBookEntry;
    }

    return movegen.Move{
        .source = @enumFromInt(entry.source),
        .target = @enumFromInt(entry.target),
        .piece = @enumFromInt(entry.piece),
        .promotionPiece = switch (entry.promotion) {
            1 => .queen,
            2 => .rook,
            3 => .bishop,
            4 => .knight,
            else => .none,
        },
        .moveType = @enumFromInt(entry.moveType),
        .isCheck = false,
        .isDiscoveryCheck = false,
        .isDoubleCheck = false,
        .capturedPiece = .none,
    };
}
