const std = @import("std");
const bitboard = @import("bitboard.zig");
const utils = @import("utils.zig");
const atk = @import("attacks.zig");

pub fn generateMoves() void {
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;

    var bitboardCopy: u64 = undefined;
    var attacks: u64 = undefined;

    for (0..12) |piece| {
        bitboardCopy = bitboard.bitboards[piece];

        if (bitboard.sideToMove == @intFromEnum(bitboard.side.white)) {
            if (piece == @intFromEnum(bitboard.pieceEncoding.P)) {
                while (bitboardCopy != 0) {
                    sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
                    targetSquare = sourceSquare - 8;

                    if (!(targetSquare < @intFromEnum(bitboard.boardSquares.a8)) and utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], targetSquare) == 0) {
                        if (sourceSquare >= @intFromEnum(bitboard.boardSquares.a7) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h7)) {
                            std.debug.print("pawn promotion: {s}{s}q\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}r\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}n\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}b\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        } else {
                            std.debug.print("pawn push: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            if ((sourceSquare >= @intFromEnum(bitboard.boardSquares.a2) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h2)) and utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], targetSquare - 8) == 0) {
                                std.debug.print("double pawn push: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare - 8] });
                            }
                        }
                    }
                    attacks = atk.pawnAttacks[@intCast(bitboard.sideToMove)][sourceSquare] & bitboard.occupancies[@intFromEnum(bitboard.side.black)];
                    while (attacks != 0) {
                        targetSquare = @intCast(utils.getLSBindex(attacks));
                        if (sourceSquare >= @intFromEnum(bitboard.boardSquares.a7) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h7)) {
                            std.debug.print("pawn promotion capture: {s}{s}q\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}r\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}n\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}b\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        } else {
                            std.debug.print("pawn capture: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        }

                        utils.popBit(&attacks, targetSquare);
                    }

                    if (bitboard.enpassant != @intFromEnum(bitboard.boardSquares.noSquare)) {
                        const enpassantAttacks: u64 = atk.pawnAttacks[@intCast(bitboard.sideToMove)][sourceSquare] & (@as(u64, 1) << @intCast(bitboard.enpassant));
                        if (enpassantAttacks != 0) {
                            const targetEnpassant: u6 = @intCast(utils.getLSBindex(enpassantAttacks));
                            std.debug.print("pawn enpassant capture: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetEnpassant] });
                        }
                    }
                    utils.popBit(&bitboardCopy, sourceSquare);
                }
            }
        } else {
            if (piece == @intFromEnum(bitboard.pieceEncoding.p)) {
                while (bitboardCopy != 0) {
                    sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
                    targetSquare = sourceSquare + 8;

                    if (!(targetSquare > @intFromEnum(bitboard.boardSquares.h1)) and utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], targetSquare) == 0) {
                        if (sourceSquare >= @intFromEnum(bitboard.boardSquares.a2) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h2)) {
                            std.debug.print("pawn promotion: {s}{s}q\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}r\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}n\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion: {s}{s}b\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        } else {
                            std.debug.print("pawn push: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            if ((sourceSquare >= @intFromEnum(bitboard.boardSquares.a7) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h7)) and utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], targetSquare + 8) == 0) {
                                std.debug.print("double pawn push: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare + 8] });
                            }
                        }
                    }
                    attacks = atk.pawnAttacks[@intCast(bitboard.sideToMove)][sourceSquare] & bitboard.occupancies[@intFromEnum(bitboard.side.white)];
                    while (attacks != 0) {
                        targetSquare = @intCast(utils.getLSBindex(attacks));
                        if (sourceSquare >= @intFromEnum(bitboard.boardSquares.a2) and sourceSquare <= @intFromEnum(bitboard.boardSquares.h2)) {
                            std.debug.print("pawn promotion capture: {s}{s}q\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}r\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}n\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                            std.debug.print("pawn promotion capture: {s}{s}b\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        } else {
                            std.debug.print("pawn capture: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                        }

                        utils.popBit(&attacks, targetSquare);
                    }

                    if (bitboard.enpassant != @intFromEnum(bitboard.boardSquares.noSquare)) {
                        const enpassantAttacks: u64 = atk.pawnAttacks[@intCast(bitboard.sideToMove)][sourceSquare] & (@as(u64, 1) << @intCast(bitboard.enpassant));
                        if (enpassantAttacks != 0) {
                            const targetEnpassant: u6 = @intCast(utils.getLSBindex(enpassantAttacks));
                            std.debug.print("pawn enpassant capture: {s}{s}\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetEnpassant] });
                        }
                    }
                    utils.popBit(&bitboardCopy, sourceSquare);
                }
            }
        }
    }
}
