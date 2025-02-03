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
const syzygy = @import("syzygy.zig");

pub const ENGINE_NAME = "Kirin Chess";
pub const ENGINE_AUTHOR = "Strydr Silverberg";

pub const RESIGN_THRESHOLD: i32 = -500; // Resign if eval is worse than -10 pawns
pub const RESIGN_PLIES: u8 = 4;

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

const ResignTracker = struct {
    bad_positions: u8 = 0,
    prev_eval: i32 = 0,

    pub fn shouldResign(self: *ResignTracker, eval: i32) bool {
        if (eval < RESIGN_THRESHOLD) {
            self.bad_positions += 1;
            if (self.bad_positions >= RESIGN_PLIES and
                self.prev_eval < RESIGN_THRESHOLD)
            {
                return true;
            }
        } else {
            self.bad_positions = 0;
        }
        self.prev_eval = eval;
        return false;
    }

    pub fn reset(self: *ResignTracker) void {
        self.bad_positions = 0;
        self.prev_eval = 0;
    }
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
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    // Create transposition table
    var tt = transposition.TranspositionTable.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var opening_book = syzygy.OpeningBook.init(gpa.allocator());
    defer opening_book.deinit();

    var searchActive = false;
    var timer = std.time.Timer.start() catch |err| {
        try stdout.print("info string Error initializing timer: {}\n", .{err});
        return;
    };

    // Print engine info
    try stdout.print("id name {s}\n", .{ENGINE_NAME});
    try stdout.print("id author {s}\n", .{ENGINE_AUTHOR});
    try stdout.print("uciok\n", .{});

    // Fixed buffer for input
    var buffer: [2000]u8 = undefined;
    var resignTracker = ResignTracker{};

    while (true) {
        // Get user/GUI input
        const input = stdin.readUntilDelimiter(&buffer, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try stdout.print("info string Input too long\n", .{});
                try stdin.skipUntilDelimiterOrEof('\n');
                continue;
            },
            else => |e| return e,
        };

        // Skip empty lines
        if (input.len == 0) {
            continue;
        }

        // Parse UCI commands
        if (std.mem.eql(u8, input, "isready")) {
            try stdout.print("readyok\n", .{});
        } else if (std.mem.startsWith(u8, input, "position")) {
            parsePosition(input, gameBoard, attackTable) catch |err| {
                try stdout.print("info string Error processing position: {}\n", .{err});
                continue;
            };
        } else if (std.mem.eql(u8, input, "ucinewgame")) {
            parsePosition("position startpos", gameBoard, attackTable) catch |err| {
                try stdout.print("info string Error resetting position: {}\n", .{err});
                continue;
            };
            // Clear transposition table for new game
            tt.clear();
            resignTracker.reset();
        } else if (std.mem.startsWith(u8, input, "setoption name BookFile value ")) {
            const filename = input["setoption name BookFile value ".len..];
            opening_book.loadFromFile(filename) catch |err| {
                try stdout.print("info string Error loading book: {}\n", .{err});
            };
        } else if (std.mem.startsWith(u8, input, "go")) {
            const params = parseGo(input) catch |err| {
                try stdout.print("info string Error parsing go command: {}\n", .{err});
                continue;
            };

            // Calculate appropriate time for this move
            const moveTime = params.time_control.calculateMoveTime(gameBoard.sideToMove);

            // Set up search limits
            const limits = search.SearchLimits{
                .depth = @as(i8, params.time_control.depth orelse 64),
                .nodes = params.time_control.nodes,
                .movetime = if (!params.time_control.infinite) moveTime else null,
                .infinite = params.time_control.infinite,
            };

            searchActive = true;
            timer.reset();

            // Try to get a book move first
            if (try opening_book.getBookMove(gameBoard)) |book_move| {
                try stdout.print("info string using book move\n", .{});
                try stdout.print("bestmove ", .{});
                try printUciMove(stdout, book_move);
                searchActive = false;
                continue;
            }

            // No book move found, proceed with normal search
            const result = search.startSearch(gameBoard, attackTable, &tt, limits) catch |err| {
                try stdout.print("info string Search error: {}\n", .{err});
                try stdout.print("bestmove 0000\n", .{});
                searchActive = false;
                continue;
            };

            if (resignTracker.shouldResign(result.score)) {
                try stdout.print("bestmove 0000\n", .{});
                searchActive = false;
                continue;
            }

            if (result.bestMove) |best_move| {
                try stdout.print("bestmove ", .{});
                try printUciMove(stdout, best_move);
            } else {
                try stdout.print("bestmove 0000\n", .{});
            }

            searchActive = false;
        } else if (std.mem.eql(u8, input, "stop")) {
            if (searchActive) {
                // Handle stopping the search
                searchActive = false;
            }
        } else if (std.mem.eql(u8, input, "quit")) {
            break;
        } else if (std.mem.eql(u8, input, "uci")) {
            try stdout.print("id name {s}\n", .{ENGINE_NAME});
            try stdout.print("id author {s}\n", .{ENGINE_AUTHOR});
            try stdout.print("option name BookFile type string default <empty>\n", .{});
            try stdout.print("uciok\n", .{});
        } else if (std.mem.eql(u8, input, "d")) {
            // Debug command to print board
            utils.printBoard(gameBoard);
            const score = evaluation.evaluate(gameBoard);
            try stdout.print("Evaluation: {s} ({d})\n", .{
                evaluation.getEvalNotation(score),
                score,
            });
        } else {
            try stdout.print("info string Unknown command: {s}\n", .{input});
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
    depth: ?i8 = null, // Maximum depth to search
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
                tc.depth = @intCast(@min(num, 127)); // Ensure we don't overflow i8
                tc.infinite = true;
            } else if (std.mem.eql(u8, token, "nodes")) {
                tc.nodes = num;
                tc.infinite = true;
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

    // Removed the "bestmove" prefix since it's added by the caller
    try writer.print("{c}{c}{c}{c}", .{
        sourceCoords[0],
        sourceCoords[1],
        targetCoords[0],
        targetCoords[1],
    });

    if (move.moveType == movegen.MoveType.promotion or
        move.moveType == movegen.MoveType.promotionCapture)
    {
        const promo_char: u8 = switch (move.promotionPiece) {
            movegen.PromotionPiece.queen => 'q',
            movegen.PromotionPiece.rook => 'r',
            movegen.PromotionPiece.bishop => 'b',
            movegen.PromotionPiece.knight => 'n',
            movegen.PromotionPiece.none => unreachable,
        };
        try writer.print("{c}", .{promo_char});
    }
}
