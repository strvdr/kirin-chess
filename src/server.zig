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
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();

    const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 3667);
    var server = try addr.listen(.{});

    std.log.info("Server listening on port 3667", .{});

    var client = try server.accept();
    defer client.stream.close();

    const client_reader = client.stream.reader();
    const client_writer = client.stream.writer();
    while (true) {
        const msg = try client_reader.readUntilDelimiterOrEofAlloc(gpa, '\n', 65536) orelse break;
        defer gpa.free(msg);

        std.log.info("Recieved message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        try client_writer.writeAll(msg);
    }
}
