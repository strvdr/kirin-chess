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
const utils = @import("utils.zig");
const atk = @import("attacks.zig");

pub const MoveType = enum(u3) {
    quiet,
    capture,
    promotion,
    promotion_capture,
    double_push,
    en_passant,
};

pub const PromotionPiece = enum(u3) {
    none = 0,
    queen = 1,
    rook = 2,
    bishop = 3,
    knight = 4,
};

pub const Move = packed struct {
    from: bitboard.Square,
    to: bitboard.Square,
    piece: bitboard.Piece,
    promotion_piece: PromotionPiece = .none,
    move_type: MoveType,

    pub fn print(self: Move) void {
        const source_coords = self.from.toCoordinates() catch return;
        const target_coords = self.to.toCoordinates() catch return;

        const piece_name = switch (self.piece) {
            .P, .p => "pawn",
            .R, .r => "rook",
            .B, .b => "bishop",
            .N, .n => "knight",
            .Q, .q => "queen",
            .K, .k => "king",
        };

        switch (self.move_type) {
            .promotion, .promotion_capture => {
                const promotion_char = bitboard.Piece.toPromotionChar(@as(bitboard.Piece, @enumFromInt(@intFromEnum(self.promotion_piece))));
                std.debug.print("{s} promotion: {c}{c}{c}{c}{c}\n", .{
                    piece_name,
                    source_coords[0],
                    source_coords[1],
                    target_coords[0],
                    target_coords[1],
                    promotion_char,
                });
            },
            .double_push => {
                std.debug.print("{s} double push: {c}{c}{c}{c}\n", .{
                    piece_name,
                    source_coords[0],
                    source_coords[1],
                    target_coords[0],
                    target_coords[1],
                });
            },
            else => {
                std.debug.print("{s} {s}: {c}{c}{c}{c}\n", .{
                    piece_name,
                    if (self.move_type == .capture) "capture" else "move",
                    source_coords[0],
                    source_coords[1],
                    target_coords[0],
                    target_coords[1],
                });
            },
        }
    }
};

pub fn generatePawnMoves(
    board: *const bitboard.Board,
    attack_table: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;

    // Get pawn bitboard based on side
    const pawn_bb = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.P)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.p)];
    const opponent_pieces = board.occupancy[@intFromEnum(side.opposite())];
    var bb_copy = pawn_bb;

    // Direction of pawn movement and ranks
    const push_offset: i8 = switch (side) {
        .white => 8,
        .black => -8,
        .both => unreachable,
    };

    const promotion_rank: i8 = switch (side) {
        .white => 7,
        .black => 0,
        .both => unreachable,
    };

    const starting_rank: i8 = switch (side) {
        .white => 6,
        .black => 1,
        .both => unreachable,
    };

    while (bb_copy != 0) {
        const from = utils.getLSBindex(bb_copy);
        if (from < 0) break;
        const from_square = @as(u6, @intCast(from));

        // Single push
        const to = @as(u6, @intCast(from)) + push_offset;
        if (to >= 0 and to < 64) {
            const to_square = @as(u6, @intCast(to));
            if (utils.getBit(board.occupancy[2], to_square) == 0) {
                const rank = @divFloor(@as(i8, to), 8);
                if (rank == promotion_rank) {
                    // Promotion moves
                    inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotion_piece| {
                        callback(context, .{
                            .from = @as(bitboard.Square, @enumFromInt(from_square)),
                            .to = @as(bitboard.Square, @enumFromInt(to_square)),
                            .piece = if (side == .white) .P else .p,
                            .promotion_piece = promotion_piece,
                            .move_type = .promotion,
                        });
                    }
                } else {
                    // Normal push
                    callback(context, .{
                        .from = @as(bitboard.Square, @enumFromInt(from_square)),
                        .to = @as(bitboard.Square, @enumFromInt(to_square)),
                        .piece = if (side == .white) .P else .p,
                        .move_type = .quiet,
                    });

                    // Double push
                    const current_rank = @divFloor(@as(i8, from), 8);
                    if (current_rank == starting_rank) {
                        const double_to = to + push_offset;
                        if (double_to >= 0 and double_to < 64) {
                            const double_to_square = @as(u6, @intCast(double_to));
                            if (utils.getBit(board.occupancy[2], double_to_square) == 0) {
                                callback(context, .{
                                    .from = @as(bitboard.Square, @enumFromInt(from_square)),
                                    .to = @as(bitboard.Square, @enumFromInt(double_to_square)),
                                    .piece = if (side == .white) .P else .p,
                                    .move_type = .double_push,
                                });
                            }
                        }
                    }
                }
            }
        }

        // Captures
        const attacks = attack_table.pawn[@intFromEnum(side)][@intCast(from)] & opponent_pieces;
        var attack_bb = attacks;
        while (attack_bb != 0) {
            const to_capture = utils.getLSBindex(attack_bb);
            if (to_capture < 0) break;

            const to_square = @as(u6, @intCast(to_capture));
            const rank = @divFloor(@as(i8, to_capture), 8);

            if (rank == promotion_rank) {
                inline for ([_]PromotionPiece{ .queen, .rook, .bishop, .knight }) |promotion_piece| {
                    callback(context, .{
                        .from = @as(bitboard.Square, @enumFromInt(from)),
                        .to = @as(bitboard.Square, @enumFromInt(to_square)),
                        .piece = if (side == .white) .P else .p,
                        .promotion_piece = promotion_piece,
                        .move_type = .promotion_capture,
                    });
                }
            } else {
                // Normal captures
                callback(context, .{
                    .from = @as(bitboard.Square, @enumFromInt(from)),
                    .to = @as(bitboard.Square, @enumFromInt(to_square)),
                    .piece = if (side == .white) .P else .p,
                    .move_type = .capture,
                });
            }

            attack_bb &= attack_bb - 1; // Clear LSB
        }

        // En passant
        if (board.enpassant != .noSquare) {
            const ep_attacks = attack_table.pawn[@intFromEnum(side)][@intCast(from)] &
                (@as(u64, 1) << @intCast(@intFromEnum(board.enpassant)));
            if (ep_attacks != 0) {
                callback(context, .{
                    .from = @as(bitboard.Square, @enumFromInt(from)),
                    .to = board.enpassant,
                    .piece = if (side == .white) .P else .p,
                    .move_type = .en_passant,
                });
            }
        }

        bb_copy &= bb_copy - 1; // Clear LSB
    }
}

pub fn generateKnightMoves(
    board: *const bitboard.Board,
    attack_table: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponent_pieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get knights bitboard for current side
    const knights_bb = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.N)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.n)];

    var bb_copy = knights_bb;
    while (bb_copy != 0) {
        const from = utils.getLSBindex(bb_copy);
        if (from < 0) break;
        const from_square = @as(u6, @intCast(from));

        // Get all possible moves for this knight
        const moves = attack_table.knight[from_square];

        // Split into captures and quiet moves
        const captures = moves & opponent_pieces;
        const quiet_moves = moves & ~board.occupancy[2]; // All empty squares

        // Process captures
        var captures_bb = captures;
        while (captures_bb != 0) {
            const to = utils.getLSBindex(captures_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (side == .white) .N else .n,
                .move_type = .capture,
            });

            captures_bb &= captures_bb - 1;
        }

        // Process quiet moves
        var quiet_bb = quiet_moves;
        while (quiet_bb != 0) {
            const to = utils.getLSBindex(quiet_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (side == .white) .N else .n,
                .move_type = .quiet,
            });

            quiet_bb &= quiet_bb - 1;
        }

        bb_copy &= bb_copy - 1;
    }
}

pub fn generateKingMoves(
    board: *const bitboard.Board,
    attack_table: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
) void {
    const side = board.sideToMove;
    const opponent_pieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get king bitboard for current side
    const king_bb = if (side == .white)
        board.bitboard[@intFromEnum(bitboard.Piece.K)]
    else
        board.bitboard[@intFromEnum(bitboard.Piece.k)];

    var bb_copy = king_bb;
    while (bb_copy != 0) {
        const from = utils.getLSBindex(bb_copy);
        if (from < 0) break;
        const from_square = @as(u6, @intCast(from));

        // Get all possible moves for this king
        const moves = attack_table.king[from_square];

        // Split into captures and quiet moves
        const captures = moves & opponent_pieces;
        const quiet_moves = moves & ~board.occupancy[2];

        // Process captures
        var captures_bb = captures;
        while (captures_bb != 0) {
            const to = utils.getLSBindex(captures_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (side == .white) .K else .k,
                .move_type = .capture,
            });

            captures_bb &= captures_bb - 1;
        }

        // Process quiet moves
        var quiet_bb = quiet_moves;
        while (quiet_bb != 0) {
            const to = utils.getLSBindex(quiet_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (side == .white) .K else .k,
                .move_type = .quiet,
            });

            quiet_bb &= quiet_bb - 1;
        }

        bb_copy &= bb_copy - 1;
    }
}

pub fn generateSlidingMoves(
    board: *const bitboard.Board,
    attack_table: *const atk.AttackTable,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Move) void,
    is_bishop: bool,
) void {
    const side = board.sideToMove;
    const friendly_pieces = board.occupancy[@intFromEnum(side)];
    const opponent_pieces = board.occupancy[@intFromEnum(side.opposite())];

    // Get piece bitboard based on side and type
    const piece_bb = if (is_bishop)
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.B)] else board.bitboard[@intFromEnum(bitboard.Piece.b)])
    else
        (if (side == .white) board.bitboard[@intFromEnum(bitboard.Piece.R)] else board.bitboard[@intFromEnum(bitboard.Piece.r)]);

    var bb_copy = piece_bb;
    while (bb_copy != 0) {
        const from = utils.getLSBindex(bb_copy);
        if (from < 0) break;
        const from_square = @as(u6, @intCast(from));

        // Get all possible moves considering current occupancy
        const moves = if (is_bishop)
            atk.getBishopAttacks(from_square, board.occupancy[2], attack_table)
        else
            atk.getRookAttacks(from_square, board.occupancy[2], attack_table);

        // Remove moves to squares with friendly pieces
        const legal_moves = moves & ~friendly_pieces;

        // First generate captures
        var captures_bb = legal_moves & opponent_pieces;
        while (captures_bb != 0) {
            const to = utils.getLSBindex(captures_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .move_type = .capture,
            });

            captures_bb &= captures_bb - 1;
        }

        // Then generate quiet moves (moves to empty squares)
        var quiet_bb = legal_moves & ~opponent_pieces; // Changed from board.occupancy[2]
        while (quiet_bb != 0) {
            const to = utils.getLSBindex(quiet_bb);
            if (to < 0) break;
            const to_square = @as(u6, @intCast(to));

            callback(context, .{
                .from = @as(bitboard.Square, @enumFromInt(from_square)),
                .to = @as(bitboard.Square, @enumFromInt(to_square)),
                .piece = if (is_bishop)
                    (if (side == .white) .B else .b)
                else
                    (if (side == .white) .R else .r),
                .move_type = .quiet,
            });

            quiet_bb &= quiet_bb - 1;
        }

        bb_copy &= bb_copy - 1;
    }
}
