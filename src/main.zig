const std = @import("std");
const netpkg = @import("net");
const UdpServer = netpkg.UdpServer;
const UdpClient = netpkg.UdpClient;
const TcpServer = netpkg.TcpServer;
const TcpClient = netpkg.TcpClient;
const DataPacker = netpkg.DataPacker;
const AtomicBool = std.atomic.Value(bool);

const signal_h = @cImport(@cInclude("signal.h"));

var dp: DataPacker = blk: {
    var dp_blk: DataPacker = .init("nejtajnejsiheslouwu", "uwu", null);
    dp_blk.keyValueMode(null);

    break :blk dp_blk;
};

var udp: UdpServer = undefined;
var tcp: TcpServer = undefined;

var gpa = std.heap.DebugAllocator(.{}).init;
const allocator: std.mem.Allocator = gpa.allocator();

const server_port = 6969;
const server_name = "vlcaak";

var exit_flag: AtomicBool = .init(false);

pub fn main() !void {
    udp = try .open("0.0.0.0", server_port);
    udp.dispatch_fn = dispatchUdp;
    try udp.listen();

    tcp = try .open("0.0.0.0", server_port, allocator);
    tcp.dispatch_fn = dispatchTcp;
    try tcp.listen();

    _ = signal_h.signal(signal_h.SIGINT, onInterrupt);

    while (true) {
        const line = std.io.getStdIn().reader().readUntilDelimiterAlloc(allocator, '\n', ~@as(usize, 0)) catch |err| switch (err) {
            // break loop on interrupt
            std.io.StreamSource.Reader.NoEofError.EndOfStream => break,
            else => return err,
        };
        defer allocator.free(line);
    }

    exit_flag.store(true, .release);

    // please wait for interrupt routine to clean up (to see the output in console)
    while (exit_flag.load(.acquire)) {}
}

fn onInterrupt(sig_num: c_int) callconv(.c) void {
    _ = sig_num;

    // wait for main to almost reach the end of its execution
    while (!exit_flag.load(.acquire)) {}

    udp.close();
    tcp.close();

    _ = gpa.deinit();

    exit_flag.store(false, .release);
}

fn dispatchUdp(server: *const UdpServer, sender_addr: std.net.Ip4Address, data: []const u8) anyerror!void {
    _ = server;

    std.log.info("received message via udp from {}:", .{sender_addr});
    std.log.info("{s}", .{data});

    const decoded = try dp.whichevercrypt(data, allocator);
    defer allocator.free(decoded);

    std.log.info("{s}", .{decoded});

    if (!dp.verify(decoded)) {
        std.log.warn("invalid data received via udp", .{});
        return;
    }

    var iter = dp.iteratorOver(decoded);
    if (dp.valueOf(decoded, "s") != null) {
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

fn dispatchTcp(server: *TcpServer, connection: *TcpServer.Connection, data: []const u8) anyerror!void {
    _ = server;

    std.log.info("received message via tcp from {}:", .{connection.client_ip4});
    std.log.info("{s}", .{data});

    const decoded = try dp.whichevercrypt(data, allocator);
    defer allocator.free(decoded);

    std.log.info("{s}", .{decoded});

    if (!dp.verify(decoded)) {
        std.log.warn("invalid data received via tcp", .{});
        return;
    }

    var iter = dp.iteratorOver(decoded);
    _ = &iter;
    if (dp.valueOf(decoded, "die") != null) {
        connection.awaits_disposal.store(true, .release);
    }
}
