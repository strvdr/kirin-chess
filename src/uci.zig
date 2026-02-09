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
const movegen = @import("movegen.zig");
const attacks = @import("attacks.zig");
const utils = @import("utils.zig");
const evaluation = @import("evaluation.zig");
const search = @import("search.zig");
const transposition = @import("transposition.zig");

pub const ENGINE_NAME = "Kirin Chess";
pub const ENGINE_AUTHOR = "Strydr Silverberg";

pub const MoveParseError = error{
    InvalidMoveString,
    InvalidSourceSquare,
    InvalidTargetSquare,
    IllegalMove,
    InvalidPromotion,
};

pub const PositionParseError = error{
    InvalidCommand,
    InvalidFEN,
    InvalidMove,
};

pub const GoParseError = error{
    InvalidCommand,
    InvalidDepth,
};
/// Parses a move string in the format "e2e4" or "e7e8q" for promotions
/// Returns the corresponding Move struct if the move is legal
pub fn parseMove(
    moveString: []const u8,
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
) !movegen.Move {
    // Validate move string length
    if (moveString.len < 4) {
        return MoveParseError.InvalidMoveString;
    }

    // Parse source square
    const sourceFile = moveString[0] - 'a';
    const sourceRank = '8' - moveString[1];
    if (sourceFile >= 8 or sourceRank >= 8) {
        return MoveParseError.InvalidSourceSquare;
    }
    const sourceSquare = @as(u6, @intCast(sourceRank * 8 + sourceFile));

    // Parse target square
    const targetFile = moveString[2] - 'a';
    const targetRank = '8' - moveString[3];
    if (targetFile >= 8 or targetRank >= 8) {
        return MoveParseError.InvalidTargetSquare;
    }
    const targetSquare = @as(u6, @intCast(targetRank * 8 + targetFile));

    // Generate all legal moves
    var moveList = movegen.MoveList.init();
    search.generateAllMoves(gameBoard, attackTable, &moveList);

    // Look for matching move in the generated moves
    for (moveList.getMoves()) |move| {
        if (@intFromEnum(move.source) == sourceSquare and @intFromEnum(move.target) == targetSquare) {
            // Handle promotions
            if (move.moveType == .promotion or move.moveType == .promotionCapture) {
                if (moveString.len < 5) {
                    return MoveParseError.InvalidPromotion;
                }

                // Check if the promotion piece matches
                const promotionChar = moveString[4];
                const expectedPromotionPiece = switch (promotionChar) {
                    'q' => movegen.PromotionPiece.queen,
                    'r' => movegen.PromotionPiece.rook,
                    'b' => movegen.PromotionPiece.bishop,
                    'n' => movegen.PromotionPiece.knight,
                    else => return MoveParseError.InvalidPromotion,
                };

                if (move.promotionPiece != expectedPromotionPiece) {
                    continue;
                }
            }

            return move;
        }
    }

    return MoveParseError.IllegalMove;
}

/// Parses UCI "position" command and updates the board state accordingly
/// Example commands:
///   "position startpos"
///   "position startpos moves e2e4 e7e5"
///   "position fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
///   "position fen ... moves e2a6 e8g8"
pub fn parsePosition(
    command: []const u8,
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
) !void {
    // Check minimum command length
    if (command.len < 9 or !std.mem.startsWith(u8, command, "position ")) {
        return PositionParseError.InvalidCommand;
    }

    // Skip "position " prefix
    var current: usize = 9;

    // Handle startpos
    if (std.mem.startsWith(u8, command[current..], "startpos")) {
        try utils.parseFEN(gameBoard, bitboard.Position.start);
        current += 8; // Skip "startpos"
    } else if (std.mem.startsWith(u8, command[current..], "fen")) {
        // Skip "fen " and find the end of FEN string (either at "moves" or end of command)
        current += 4; // Skip "fen "

        // Skip any leading spaces
        while (current < command.len and command[current] == ' ') {
            current += 1;
        }

        // Find the end of the FEN string
        const fenEnd = findFenEnd(command[current..]);
        try utils.parseFEN(gameBoard, command[current..][0..fenEnd]);
        current += fenEnd;
    } else {
        // If neither startpos nor fen is specified, use starting position
        try utils.parseFEN(gameBoard, bitboard.Position.start);
    }

    // Look for "moves" section
    if (findMoves(command[current..])) |movesStart| {
        current += movesStart + 6; // Skip "moves " and any leading spaces

        // Process each move
        while (current < command.len) {
            // Skip spaces
            while (current < command.len and command[current] == ' ') {
                current += 1;
            }
            if (current >= command.len) break;

            // Find end of move string
            var moveEnd = current;
            while (moveEnd < command.len and command[moveEnd] != ' ') {
                moveEnd += 1;
            }

            if (moveEnd > current) {
                const move = try parseMove(command[current..moveEnd], gameBoard, attackTable);
                try gameBoard.makeMove(move);
                current = moveEnd;
            }
        }
    }
}

/// Finds the end index of the FEN string
fn findFenEnd(str: []const u8) usize {
    var spaceCount: usize = 0;
    for (str, 0..) |c, i| {
        if (c == ' ') {
            spaceCount += 1;
            if (spaceCount == 6 or std.mem.startsWith(u8, str[i..], " moves")) {
                return i;
            }
        }
    }
    return str.len;
}

/// Finds the start of the moves section, if it exists
fn findMoves(str: []const u8) ?usize {
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (std.mem.startsWith(u8, str[i..], "moves")) {
            return i;
        }
    }
    return null;
}

pub fn uciLoop(gameBoard: *bitboard.Board, attackTable: *attacks.AttackTable) !void {
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    // Create transposition table
    var tt = transposition.TranspositionTable.init();

    // Print engine info
    try stdout_file.writeAll("id name " ++ ENGINE_NAME ++ "\n");
    try stdout_file.writeAll("id author " ++ ENGINE_AUTHOR ++ "\n");
    try stdout_file.writeAll("uciok\n");

    var buffer: [4096]u8 = undefined;

    while (true) {
        // Read a line manually
        var len: usize = 0;
        while (len < buffer.len) {
            var byte: [1]u8 = undefined;
            const bytes_read = stdin_file.read(&byte) catch break;
            if (bytes_read == 0) break; // EOF
            if (byte[0] == '\n') break;
            buffer[len] = byte[0];
            len += 1;
        }

        if (len == 0) continue;

        // Trim carriage return if present (Windows line endings)
        const trimmed = std.mem.trimRight(u8, buffer[0..len], "\r");

        // Skip empty lines
        if (trimmed.len == 0) {
            continue;
        }

        // Parse UCI commands
        if (std.mem.eql(u8, trimmed, "isready")) {
            try stdout_file.writeAll("readyok\n");
        } else if (std.mem.startsWith(u8, trimmed, "position")) {
            parsePosition(trimmed, gameBoard, attackTable) catch {
                try stdout_file.writeAll("info string Error processing position\n");
                continue;
            };
        } else if (std.mem.eql(u8, trimmed, "ucinewgame")) {
            parsePosition("position startpos", gameBoard, attackTable) catch {
                try stdout_file.writeAll("info string Error resetting position\n");
                continue;
            };
            tt.clear();
        } else if (std.mem.startsWith(u8, trimmed, "go")) {
            const params = parseGo(trimmed) catch {
                try stdout_file.writeAll("info string Error parsing go command\n");
                continue;
            };

            const moveTime = params.time_control.calculateMoveTime(gameBoard.sideToMove);

            const limits = search.SearchLimits{
                .depth = params.time_control.depth orelse 64,
                .nodes = params.time_control.nodes,
                .movetime = if (!params.time_control.infinite) moveTime else null,
                .infinite = params.time_control.infinite,
            };

            const result = search.startSearch(gameBoard, attackTable, &tt, limits) catch {
                try stdout_file.writeAll("info string Search error\n");
                try stdout_file.writeAll("bestmove 0000\n");
                continue;
            };

            if (result.bestMove) |best_move| {
                var moveStr: [16]u8 = undefined;

                const sourceCoords = best_move.source.toCoordinates() catch {
                    try stdout_file.writeAll("bestmove 0000\n");
                    continue;
                };
                const targetCoords = best_move.target.toCoordinates() catch {
                    try stdout_file.writeAll("bestmove 0000\n");
                    continue;
                };

                var idx: usize = 0;
                const prefix = "bestmove ";
                @memcpy(moveStr[0..prefix.len], prefix);
                idx = prefix.len;

                moveStr[idx] = sourceCoords[0];
                moveStr[idx + 1] = sourceCoords[1];
                moveStr[idx + 2] = targetCoords[0];
                moveStr[idx + 3] = targetCoords[1];
                idx += 4;

                if (best_move.moveType == movegen.MoveType.promotion or best_move.moveType == movegen.MoveType.promotionCapture) {
                    moveStr[idx] = switch (best_move.promotionPiece) {
                        movegen.PromotionPiece.queen => 'q',
                        movegen.PromotionPiece.rook => 'r',
                        movegen.PromotionPiece.bishop => 'b',
                        movegen.PromotionPiece.knight => 'n',
                        movegen.PromotionPiece.none => ' ',
                    };
                    idx += 1;
                }

                moveStr[idx] = '\n';
                idx += 1;

                try stdout_file.writeAll(moveStr[0..idx]);
            } else {
                try stdout_file.writeAll("bestmove 0000\n");
            }
        } else if (std.mem.eql(u8, trimmed, "quit")) {
            break;
        } else if (std.mem.eql(u8, trimmed, "uci")) {
            try stdout_file.writeAll("id name " ++ ENGINE_NAME ++ "\n");
            try stdout_file.writeAll("id author " ++ ENGINE_AUTHOR ++ "\n");
            try stdout_file.writeAll("uciok\n");
        } else if (std.mem.eql(u8, trimmed, "d")) {
            utils.printBoard(gameBoard);
            const score = evaluation.evaluate(gameBoard);
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Evaluation: {s} ({d})\n", .{
                evaluation.getEvalNotation(score),
                score,
            }) catch "Evaluation error\n";
            try stdout_file.writeAll(msg);
        } else {
            try stdout_file.writeAll("info string Unknown command: ");
            try stdout_file.writeAll(trimmed);
            try stdout_file.writeAll("\n");
        }
    }
}

pub const TimeControl = struct {
    wtime: ?u64 = null, // Time left for white in ms
    btime: ?u64 = null, // Time left for black in ms
    winc: ?u64 = null, // White increment per move in ms
    binc: ?u64 = null, // Black increment per move in ms
    movestogo: ?u32 = null, // Moves until next time control
    movetime: ?u64 = null, // Exact time to use for this move
    depth: ?u8 = null, // Maximum depth to search
    nodes: ?u64 = null, // Maximum nodes to search
    infinite: bool = false, // Search until "stop" command

    pub fn calculateMoveTime(self: TimeControl, side: bitboard.Side) u64 {
        // If exact move time is specified, use that
        if (self.movetime) |mt| {
            return mt;
        }

        // Get time and increment for current side
        const timeLeft = if (side == .white) self.wtime else self.btime;
        const increment = if (side == .white) self.winc else self.binc;

        if (timeLeft) |time| {
            var moveTime: u64 = undefined;

            // Basic time management
            if (self.movestogo) |moves| {
                // Allocate time evenly among remaining moves
                moveTime = @max(time / moves, time / 50);
                if (increment) |inc| {
                    moveTime +%= inc / 2; // Use some increment, save some
                }
            } else {
                // Estimate we have about 40 moves left
                moveTime = time / 30;
                if (increment) |inc| {
                    moveTime +%= inc / 2;
                }
            }

            // Safety margins
            moveTime = @min(moveTime, time / 4); // Don't use more than 1/4 of remaining time
            moveTime = @max(moveTime, 10); // Minimum 100ms per move
            moveTime = @min(moveTime, time - 10); // Leave 50ms buffer

            return moveTime;
        }

        // Default to 1 second if no time control specified
        return 100;
    }
};

pub const GoCommand = struct {
    time_control: TimeControl,
};

pub fn parseGo(command: []const u8) !GoCommand {
    var tc = TimeControl{};
    var iter = std.mem.tokenizeAny(u8, command, " ");
    _ = iter.next(); // Skip "go"

    while (iter.next()) |token| {
        if (std.mem.eql(u8, token, "infinite")) {
            tc.infinite = true;
        } else if (iter.next()) |value| {
            const num = std.fmt.parseInt(u64, value, 10) catch continue;
            if (std.mem.eql(u8, token, "depth")) {
                tc.depth = @intCast(num);
                tc.infinite = true; // Add this line - depth searches should run to completion
            } else if (std.mem.eql(u8, token, "nodes")) {
                tc.nodes = num;
                tc.infinite = true; // Add this line - node-limited searches should run to completion
            } else if (std.mem.eql(u8, token, "movetime")) {
                tc.movetime = num;
            } else if (std.mem.eql(u8, token, "wtime")) {
                tc.wtime = num;
            } else if (std.mem.eql(u8, token, "btime")) {
                tc.btime = num;
            } else if (std.mem.eql(u8, token, "winc")) {
                tc.winc = num;
            } else if (std.mem.eql(u8, token, "binc")) {
                tc.binc = num;
            } else if (std.mem.eql(u8, token, "movestogo")) {
                tc.movestogo = @intCast(num);
            }
        }
    }

    return GoCommand{ .time_control = tc };
}

fn printUciMove(writer: anytype, move: movegen.Move) !void {
    const sourceCoords = try move.source.toCoordinates();
    const targetCoords = try move.target.toCoordinates();

    try writer.print("bestmove {c}{c}{c}{c}", .{
        sourceCoords[0],
        sourceCoords[1],
        targetCoords[0],
        targetCoords[1],
    });

    // Here we need to use the proper movegen identifiers
    if (move.moveType == movegen.MoveType.promotion or
        move.moveType == movegen.MoveType.promotionCapture)
    {
        const promo_char = switch (move.promotionPiece) {
            movegen.PromotionPiece.queen => 'q',
            movegen.PromotionPiece.rook => 'r',
            movegen.PromotionPiece.bishop => 'b',
            movegen.PromotionPiece.knight => 'n',
            movegen.PromotionPiece.none => unreachable,
        };
        try writer.print("{c}", .{promo_char});
    }

    try writer.print("\n", .{});
}
