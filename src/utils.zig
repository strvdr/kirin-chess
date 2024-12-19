const std = @import("std");

pub fn printBitboard(bitboard: u64) !void {
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            var isOccupied: u1 = undefined;
            if (file == 0) std.debug.print("  {d}  ", .{8 - rank});
            if ((bitboard & (@as(u64, 1) << square)) != 0) isOccupied = 1 else isOccupied = 0;
            std.debug.print(" {d} ", .{isOccupied});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n      a  b  c  d  e  f  g  h \n\n", .{});

    //print bitboard as unsigned decimal number
    std.debug.print("      Bitboard: {d}\n", .{bitboard});
}
