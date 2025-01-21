const std = @import("std");
const bitboard = @import("bitboard.zig");
const movegen = @import("movegen.zig");
const attacks = @import("attacks.zig");
const utils = @import("utils.zig");
const evaluation = @import("evaluation.zig");
const search = @import("search.zig");

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

pub const GoCommand = struct {
    depth: u8,
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

pub const SearchLimits = struct {
    depth: u8 = 6, // Default depth
};

pub const SearchError = error{
    SearchStopped,
};
/// Main search function that initiates negamax search
pub fn startSearch(
    gameBoard: *bitboard.Board,
    attackTable: *const attacks.AttackTable,
    limits: SearchLimits,
) !search.SearchInfo {
    var info = search.SearchInfo{
        .depth = limits.depth,
    };

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Starting search to depth {d}\n", .{limits.depth});

    // Iterative deepening
    var depth: u8 = 1;
    while (depth <= limits.depth and !info.shouldStop) : (depth += 1) {
        try stdout.print("Searching depth {d}...\n", .{depth});

        const score = try search.pvSearch(
            gameBoard,
            attackTable,
            depth,
            0,
            -search.INFINITY,
            search.INFINITY,
            true,
            &info,
        );

        // Print info and flush
        try stdout.print(
            "info depth {d} score cp {d} nodes {d}\n",
            .{ depth, score, info.nodes },
        );
        //try std.io.getStdOut().flush();
    }

    try stdout.print("Search completed\n", .{});
    //try std.io.getStdOut().flush();

    return info;
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

/// Parses UCI "go" command and returns search parameters
/// Currently supports:
///   - "go depth N" - search to fixed depth N
///   - "go" - search to default depth (6)
pub fn parseGo(command: []const u8) !GoCommand {
    // Check minimum command length
    if (command.len < 2 or !std.mem.startsWith(u8, command, "go")) {
        return GoParseError.InvalidCommand;
    }

    // Default depth if no depth specified
    var depth: u8 = 6;

    // Look for depth parameter
    if (std.mem.indexOf(u8, command, "depth")) |depthIndex| {
        var numStart = depthIndex + 5;
        // Skip spaces after "depth"
        while (numStart < command.len and command[numStart] == ' ') {
            numStart += 1;
        }

        if (numStart < command.len) {
            // Find end of number
            var numEnd = numStart;
            while (numEnd < command.len and std.ascii.isDigit(command[numEnd])) {
                numEnd += 1;
            }

            // Parse the depth number
            depth = std.fmt.parseInt(u8, command[numStart..numEnd], 10) catch {
                return GoParseError.InvalidDepth;
            };
        }
    }

    return GoCommand{ .depth = depth };
}

pub const ENGINE_NAME = "Kirin Chess";
pub const ENGINE_AUTHOR = "Strydr Silverberg";

pub fn uciLoop(gameBoard: *bitboard.Board, attackTable: *attacks.AttackTable) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    // Print engine info
    try stdout.print("id name {s}\n", .{ENGINE_NAME});
    try stdout.print("id author {s}\n", .{ENGINE_AUTHOR});
    try stdout.print("uciok\n", .{});

    // Fixed buffer for input
    var buffer: [2000]u8 = undefined;

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
        } else if (std.mem.startsWith(u8, input, "go")) {
            const params = parseGo(input) catch |err| {
                try stdout.print("info string Error parsing go command: {}\n", .{err});
                continue;
            };

            // Set up search limits
            const limits = SearchLimits{
                .depth = params.depth,
            };

            // Perform search
            const searchInfo = startSearch(gameBoard, attackTable, limits) catch |err| {
                try stdout.print("info string Search error: {}\n", .{err});
                try stdout.print("bestmove 0000\n", .{});
                continue;
            };

            // Handle no best move found
            const bestMove = searchInfo.bestMove orelse {
                try stdout.print("info string No legal moves available\n", .{});
                try stdout.print("bestmove 0000\n", .{});
                continue;
            };

            // Convert best move to UCI format
            var moveStr: [5]u8 = undefined;
            const sourceCoords = bestMove.source.toCoordinates() catch {
                try stdout.print("bestmove 0000\n", .{});
                continue;
            };
            const targetCoords = bestMove.target.toCoordinates() catch {
                try stdout.print("bestmove 0000\n", .{});
                continue;
            };

            moveStr[0] = sourceCoords[0];
            moveStr[1] = sourceCoords[1];
            moveStr[2] = targetCoords[0];
            moveStr[3] = targetCoords[1];

            var moveLen: usize = 4;
            if (bestMove.moveType == .promotion or bestMove.moveType == .promotionCapture) {
                moveStr[4] = switch (bestMove.promotionPiece) {
                    .queen => 'q',
                    .rook => 'r',
                    .bishop => 'b',
                    .knight => 'n',
                    .none => unreachable,
                };
                moveLen = 5;
            }

            // Send the best move
            try stdout.print("bestmove ", .{});
            _ = try stdout.write(moveStr[0..moveLen]);
            try stdout.print("\n", .{});
        } else if (std.mem.eql(u8, input, "quit")) {
            break;
        } else if (std.mem.eql(u8, input, "uci")) {
            try stdout.print("id name {s}\n", .{ENGINE_NAME});
            try stdout.print("id author {s}\n", .{ENGINE_AUTHOR});
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
