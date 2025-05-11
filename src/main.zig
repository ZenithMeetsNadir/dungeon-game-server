const std = @import("std");
const udppkg = @import("udp");
const UdpServer = udppkg.UdpServer;
const DataPacker = udppkg.DataPacker;

var udp: UdpServer = undefined;
var dp: DataPacker = blk: {
    var dp_blk: DataPacker = .init("nejtajnejsiheslouwu", "uwu", null);
    dp_blk.keyValueMode(null);

    break :blk dp_blk;
};
var allocator: std.mem.Allocator = undefined;

const server_port = 6969;
const server_name = "vlcaak";

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    allocator = gpa.allocator();
    defer _ = gpa.deinit();

    udp = try .open("0.0.0.0", server_port);
    defer udp.close();

    udp.dispatch_fn = dispatch;

    try udp.listen();

    while (true) {}
}

fn dispatch(self: *const UdpServer, sender_addr: std.net.Ip4Address, data: []const u8) anyerror!void {
    _ = self;

    std.log.info("received message from {}:", .{sender_addr});
    std.log.info("{s}", .{data});

    const decoded = try dp.whichevercrypt(data, allocator);
    defer allocator.free(decoded);

    std.log.info("{s}", .{decoded});

    if (!dp.verify(decoded)) {
        std.log.warn("invalid data received", .{});
        return;
    }

    var iter = dp.iteratorOver(decoded);
    if (dp.valueOfContinue(&iter, "s") != null) {
        var msg = try dp.message(allocator);
        defer msg.deinit();

        try dp.msgAppend(&msg, server_name, "sname");

        if (dp.valueOfContinue(&iter, "t")) |tick|
            try dp.msgAppend(&msg, tick, "t");

        const encoded = try dp.whichevercrypt(msg.items, allocator);
        defer allocator.free(encoded);

        _ = try udp.sendTo(sender_addr, encoded);
    }
}
