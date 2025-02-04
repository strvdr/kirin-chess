// This file is part of the Kirin Chess project.
//
// Kirin Chess is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kirin Chess is distributed in the  hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kirin Chess.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const board = @import("bitboard.zig");
const utils = @import("utils.zig");
const assert = std.debug.assert;

/// Gets a bit value at the specified square position
/// Returns 1 if bit is set, 0 otherwise
pub fn getBit(bitboard: u64, square: u6) u1 {
    assert(square < 64);
    return @intCast((bitboard >> square) & 1);
}

/// Sets a bit at the specified square position
/// Validates input square is within bounds
pub fn setBit(bitboard: *u64, square: u6) void {
    assert(square < 64);
    bitboard.* |= (@as(u64, 1) << square);
}

/// Clears a bit at the specified square position if it is set
/// No-op if bit is already clear
pub fn popBit(bitboard: *u64, square: u6) void {
    assert(square < 64);
    bitboard.* &= ~(@as(u64, 1) << square);
}

/// Counts the number of set bits in a bitboard using built-in popcount
pub fn countBits(bitboard: u64) u6 {
    return @intCast(@popCount(bitboard));
}

/// Gets the index of the least significant set bit
/// Returns -1 if no bits are set
pub fn getLSBindex(bitboard: u64) i8 {
    return if (bitboard == 0) -1 else @intCast(@ctz(bitboard));
}

/// Creates an occupancy bitboard based on the index and attack mask
pub fn setOccupancy(index: u64, bits_in_mask: u6, attack_mask: u64) u64 {
    assert(bits_in_mask <= 64);

    var occupancy: u64 = 0;
    var attackMaskCopy = attack_mask;

    // Iterate through each bit position
    var count: u6 = 0;
    while (attackMaskCopy != 0) : (count += 1) {
        const square = @ctz(attackMaskCopy);

        // Clear the current least significant bit
        attackMaskCopy &= attackMaskCopy - 1;

        // If the corresponding bit in index is set, set the bit in occupancy
        if ((index & (@as(u64, 1) << @as(u6, @intCast(count)))) != 0) {
            occupancy |= @as(u64, 1) << @as(u6, @intCast(square));
        }
    }

    return occupancy;
}

/// Prints a visual representation of a bitboard
pub fn printBitboard(bitboard: u64) void {
    // Print rank numbers and board
    for (0..8) |rank| {
        const displayRank = 8 - rank;
        std.debug.print("  {d}  ", .{displayRank});

        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            const bit = getBit(bitboard, square);
            std.debug.print(" {d} ", .{bit});
        }
        std.debug.print("\n", .{});
    }

    // Print file letters
    std.debug.print("\n     a  b  c  d  e  f  g  h\n\n", .{});

    // Print decimal representation
    std.debug.print("Bitboard: {d}\n\n", .{bitboard});
}

/// Prints the current state of the chess board
pub fn printBoard(b: *board.Board) void {
    std.debug.print("\n", .{});

    // Print board squares
    for (0..8) |rank| {
        const displayRank = 8 - rank;
        std.debug.print("  {d} ", .{displayRank});

        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            var pieceFound = false;

            // Find piece at current square
            for (b.bitboard, 0..) |bitboard, pieceIndex| {
                if (getBit(bitboard, square) != 0) {
                    const pieceChar = getPieceChar(@as(board.Piece, @enumFromInt(pieceIndex)));
                    std.debug.print(" {c}", .{pieceChar});
                    pieceFound = true;
                    break;
                }
            }

            if (!pieceFound) {
                std.debug.print(" .", .{});
            }
        }
        std.debug.print("\n", .{});
    }

    // Print file letters
    std.debug.print("\n     a b c d e f g h\n\n", .{});

    // Print game state
    std.debug.print("Side: {s}\n", .{@tagName(b.sideToMove)});

    // Print en passant square
    if (b.enpassant != .noSquare) {
        std.debug.print("En passant: {s}\n", .{@tagName(b.enpassant)});
    } else {
        std.debug.print("En passant: no\n", .{});
    }

    // Print castling rights
    std.debug.print("Castling: {s}\n", .{castlingToString(b.castling)});
}

/// Parses a FEN string and updates the board state
pub fn parseFEN(b: *board.Board, fen: []const u8) !void {
    // Reset board state
    for (&b.bitboard) |*bitboard| {
        bitboard.* = 0;
    }
    b.occupancy = .{ 0, 0, 0 };
    b.sideToMove = .white;
    b.enpassant = .noSquare;
    b.castling = .{};

    var fenIndex: usize = 0;

    // Parse piece positions
    try parsePiecePositions(b, fen, &fenIndex);
    fenIndex += 1; // Skip space

    b.updateOccupancy();

    // Parse side to move
    try parseSideToMove(b, fen[fenIndex]);
    fenIndex += 2; // Skip side to move and space

    // Parse castling rights
    try parseCastlingRights(b, fen, &fenIndex);
    fenIndex += 1; // Skip space

    while (fen[fenIndex] == ' ') {
        fenIndex += 1;
    }

    // Parse en passant square
    const remaining_fen = fen[fenIndex..];
    if (remaining_fen.len == 0 or remaining_fen[0] == ' ') {
        return error.InvalidFEN;
    }
    try parseEnPassant(b, remaining_fen);
}

fn parsePiecePositions(b: *board.Board, fen: []const u8, fenIndex: *usize) !void {
    var rank: usize = 0; // Start at rank 8 (top of the bitboard, square 0)
    var file: usize = 0;

    while (fenIndex.* < fen.len) {
        const c = fen[fenIndex.*];

        if (c == ' ') {
            break;
        }

        if (c == '/') {
            file = 0;
            rank += 1; // Move down one rank
            fenIndex.* += 1;
            continue;
        }

        if (c >= '1' and c <= '8') {
            file += c - '0';
            fenIndex.* += 1;
        } else {
            // Convert rank and file to square number
            const square = @as(u6, @intCast(rank * 8 + file));

            const piece = charToPiece(c) orelse return error.InvalidPiece;
            utils.setBit(&b.bitboard[@intFromEnum(piece)], square);

            file += 1;
            fenIndex.* += 1;
        }
    }
}

fn castlingToString(rights: board.CastlingRights) []const u8 {
    var result: []const u8 = "";
    if (rights.whiteKingside) result = "K";
    if (rights.whiteQueenside) result = std.fmt.allocPrint(std.heap.page_allocator, "{s}Q", .{result}) catch return "error";
    if (rights.blackKingside) result = std.fmt.allocPrint(std.heap.page_allocator, "{s}k", .{result}) catch return "error";
    if (rights.blackQueenside) result = std.fmt.allocPrint(std.heap.page_allocator, "{s}q", .{result}) catch return "error";
    if (result.len == 0) return "-";
    return result;
}

fn parseSideToMove(b: *board.Board, c: u8) !void {
    b.sideToMove = switch (c) {
        'w' => .white,
        'b' => .black,
        else => return error.InvalidFEN,
    };
}

fn parseCastlingRights(b: *board.Board, fen: []const u8, fenIndex: *usize) !void {
    b.castling = .{};
    if (fen[fenIndex.*] == '-') {
        fenIndex.* += 1;
        return;
    }

    while (fen[fenIndex.*] != ' ') : (fenIndex.* += 1) {
        switch (fen[fenIndex.*]) {
            'K' => b.castling.whiteKingside = true,
            'Q' => b.castling.whiteQueenside = true,
            'k' => b.castling.blackKingside = true,
            'q' => b.castling.blackQueenside = true,
            '-' => continue,
            else => return error.InvalidFEN,
        }
    }
}

fn parseEnPassant(b: *board.Board, fenPart: []const u8) !void {
    if (fenPart.len < 1) {
        return error.InvalidFEN;
    }

    if (fenPart[0] == '-') {
        b.enpassant = .noSquare;
        return;
    }

    if (fenPart.len < 2) {
        return error.InvalidFEN;
    }

    if (fenPart[0] < 'a' or fenPart[0] > 'h') {
        return error.InvalidFEN;
    }

    if (fenPart[1] < '1' or fenPart[1] > '8') {
        return error.InvalidFEN;
    }

    const file = fenPart[0] - 'a';
    const rank = 8 - (fenPart[1] - '0');

    if (file < 0 or file >= 8 or rank < 0 or rank >= 8) {
        return error.InvalidFEN;
    }

    const squareName = std.fmt.allocPrint(std.heap.page_allocator, "{c}{c}", .{ fenPart[0], fenPart[1] }) catch return error.OutOfMemory;
    defer std.heap.page_allocator.free(squareName);

    b.enpassant = std.meta.stringToEnum(board.Square, squareName) orelse {
        return error.InvalidSquare;
    };
}

fn charToPiece(c: u8) ?board.Piece {
    return switch (c) {
        'P' => .P,
        'N' => .N,
        'B' => .B,
        'R' => .R,
        'Q' => .Q,
        'K' => .K,
        'p' => .p,
        'n' => .n,
        'b' => .b,
        'r' => .r,
        'q' => .q,
        'k' => .k,
        else => null,
    };
}

fn getPieceChar(piece: board.Piece) u8 {
    return switch (piece) {
        .P => 'P',
        .N => 'N',
        .B => 'B',
        .R => 'R',
        .Q => 'Q',
        .K => 'K',
        .p => 'p',
        .n => 'n',
        .b => 'b',
        .r => 'r',
        .q => 'q',
        .k => 'k',
    };
}
