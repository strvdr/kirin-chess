const bitboard = @import("bitboard.zig");

pub fn getRandomNumber() u32 {
    var number: u32 = bitboard.state;

    number ^= number << 13;
    number ^= number >> 17;
    number ^= number << 5;

    bitboard.state = number;

    return number;
}
