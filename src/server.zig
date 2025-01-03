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
const net = std.net;

pub fn main() !void {
    var gpaAlloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpaAlloc.deinit() == .ok);
    const gpa = gpaAlloc.allocator();

    const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 4322);
    var server = try addr.listen(.{});

    std.log.info("Server listening on port 4322", .{});

    var client = try server.accept();
    defer client.stream.close();

    const clientReader = client.stream.reader();
    const clientWriter = client.stream.writer();
    while (true) {
        const msg = try clientReader.readUntilDelimiterOrEofAlloc(gpa, '\n', 65536) orelse break;
        defer gpa.free(msg);

        std.log.info("Recieved message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        try clientWriter.writeAll(msg);
    }
}
