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
    var args = std.process.args();
    _ = args.skip();
    const port_value = args.next() orelse {
        std.debug.print("expect port as command line argument\n", .{});
        return error.NoPort;
    };

    const port = try std.fmt.parseInt(u16, port_value, 10);

    const peer = try net.Address.parseIp4("127.0.0.1", port);

    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    std.debug.print("Connecting to {}\n", .{peer});

    const data = "hello zig";
    var writer = stream.writer();
    const size = try writer.write(data);
    std.debug.print("Sending '{s}' to peer, total written: {d} bytes\n", .{ data, size });
    // Or just using `writer.writeAll`
    // try writer.writeAll("hello zig");
}
