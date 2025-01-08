const std = @import("std");
const bitboard = @import("bitboard.zig");
const utils = @import("utils.zig");
const atk = @import("attacks.zig");

fn generatePawnMoves(pawnBitboard: u64, side: u2) void {
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var bitboardCopy: u64 = pawnBitboard;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
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
    } else if (side == @intFromEnum(bitboard.side.black)) {
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

fn generateCastlingMoves(side: u2) void {
    if (side == @intFromEnum(bitboard.side.white)) {
        if (bitboard.castle & @intFromEnum(bitboard.castlingRights.wk) != 0) {
            if ((utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.f1)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.g1)) == 0)) {
                if (!atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.e1), @intFromEnum(bitboard.side.black)) and !atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.f1), @intFromEnum(bitboard.side.black))) {
                    std.debug.print("Castling move: e1g1\n", .{});
                }
            }
        }
        if (bitboard.castle & @intFromEnum(bitboard.castlingRights.wq) != 0) {
            if ((utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.d1)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.c1)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.b1)) == 0)) {
                if (!atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.e1), @intFromEnum(bitboard.side.black)) and !atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.d1), @intFromEnum(bitboard.side.black))) {
                    std.debug.print("Castling move: e1c1\n", .{});
                }
            }
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        if (bitboard.castle & @intFromEnum(bitboard.castlingRights.bk) != 0) {
            if ((utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.f8)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.g8)) == 0)) {
                if (!atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.e8), @intFromEnum(bitboard.side.white)) and !atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.f8), @intFromEnum(bitboard.side.white))) {
                    std.debug.print("Castling move: e8g8\n", .{});
                }
            }
        }
        if (bitboard.castle & @intFromEnum(bitboard.castlingRights.bq) != 0) {
            if ((utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.d8)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.c8)) == 0) and (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.both)], @intFromEnum(bitboard.boardSquares.b8)) == 0)) {
                if (!atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.e8), @intFromEnum(bitboard.side.white)) and !atk.isSquareAttacked(@intFromEnum(bitboard.boardSquares.d8), @intFromEnum(bitboard.side.white))) {
                    std.debug.print("Castling move: e8c8\n", .{});
                }
            }
        }
    }
}

fn generateKnightMoves(knightBitboard: u64, side: u2) void {
    var bitboardCopy = knightBitboard;
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.knightAttacks[sourceSquare] & ~bitboard.occupancies[@intFromEnum(bitboard.side.white)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.black)], targetSquare) == 0) {
                    std.debug.print("{s}{s} white knight quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} white knight capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.knightAttacks[sourceSquare] & ~bitboard.occupancies[@intFromEnum(bitboard.side.black)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.white)], targetSquare) == 0) {
                    std.debug.print("{s}{s} black knight quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} black knight capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
}

fn generateBishopMoves(bishopBitboard: u64, side: u2) void {
    var bitboardCopy = bishopBitboard;
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getBishopAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.white)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.black)], targetSquare) == 0) {
                    std.debug.print("{s}{s} white bishop quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} white bishop capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getBishopAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.black)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.white)], targetSquare) == 0) {
                    std.debug.print("{s}{s} black bishop quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} black bishop capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
}

fn generateRookMoves(rookBitboard: u64, side: u2) void {
    var bitboardCopy = rookBitboard;
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getRookAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.white)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.black)], targetSquare) == 0) {
                    std.debug.print("{s}{s} white rook quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} white rook capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getRookAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.black)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.white)], targetSquare) == 0) {
                    std.debug.print("{s}{s} black rook quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} black rook capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
}

fn generateQueenMoves(queenBitboard: u64, side: u2) void {
    var bitboardCopy = queenBitboard;
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getQueenAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.white)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.black)], targetSquare) == 0) {
                    std.debug.print("{s}{s} white queen quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} white queen capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.getQueenAttacks(sourceSquare, bitboard.occupancies[@intFromEnum(bitboard.side.both)]) & ~bitboard.occupancies[@intFromEnum(bitboard.side.black)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.white)], targetSquare) == 0) {
                    std.debug.print("{s}{s} black queen quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} black queen capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
}

fn generateKingMoves(kingBitboard: u64, side: u2) void {
    var bitboardCopy = kingBitboard;
    var sourceSquare: u6 = undefined;
    var targetSquare: u6 = undefined;
    var attacks: u64 = undefined;

    if (side == @intFromEnum(bitboard.side.white)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.kingAttacks[sourceSquare] & ~bitboard.occupancies[@intFromEnum(bitboard.side.white)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.black)], targetSquare) == 0) {
                    std.debug.print("{s}{s} white king quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} white king capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
    if (side == @intFromEnum(bitboard.side.black)) {
        while (bitboardCopy != 0) {
            sourceSquare = @intCast(utils.getLSBindex(bitboardCopy));
            attacks = atk.kingAttacks[sourceSquare] & ~bitboard.occupancies[@intFromEnum(bitboard.side.black)];
            while (attacks != 0) {
                targetSquare = @intCast(utils.getLSBindex(attacks));
                if (utils.getBit(bitboard.occupancies[@intFromEnum(bitboard.side.white)], targetSquare) == 0) {
                    std.debug.print("{s}{s} black king quiet move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                } else {
                    std.debug.print("{s}{s} black king capture move\n", .{ bitboard.squareCoordinates[sourceSquare], bitboard.squareCoordinates[targetSquare] });
                }
                utils.popBit(&attacks, targetSquare);
            }

            utils.popBit(&bitboardCopy, sourceSquare);
        }
    }
}

pub fn generateMoves() void {
    for (0..12) |piece| {
        const bitboardCopy: u64 = bitboard.bitboards[piece];
        if (bitboard.sideToMove == @intFromEnum(bitboard.side.white)) {
            if (piece == @intFromEnum(bitboard.pieceEncoding.P)) {
                generatePawnMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.K)) {
                generateCastlingMoves(@intFromEnum(bitboard.side.white));
                generateKingMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.N)) {
                generateKnightMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.B)) {
                generateBishopMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.R)) {
                generateRookMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.Q)) {
                generateQueenMoves(bitboardCopy, @intFromEnum(bitboard.side.white));
            }
        }
        if (bitboard.sideToMove == @intFromEnum(bitboard.side.black)) {
            if (piece == @intFromEnum(bitboard.pieceEncoding.p)) {
                generatePawnMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.k)) {
                generateCastlingMoves(@intFromEnum(bitboard.side.black));
                generateKingMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.n)) {
                generateKnightMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.b)) {
                generateBishopMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.r)) {
                generateRookMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
            if (piece == @intFromEnum(bitboard.pieceEncoding.q)) {
                generateQueenMoves(bitboardCopy, @intFromEnum(bitboard.side.black));
            }
        }
    }
}
