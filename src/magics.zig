const bitboard = @import("bitboard.zig");

pub fn getRandomNumberU32() u32 {
    var number: u32 = bitboard.state;

    number ^= number << 13;
    number ^= number >> 17;
    number ^= number << 5;

    bitboard.state = number;

    return number;
}

//from Tord Ramstad's Article on Generating Magic Numbers
pub fn getRandomNumberU64() u64 {
    const n1: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n2: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n3: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n4: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;

    return n1 | (n2 << 16) | (n3 << 32) | (n4 << 48);
}

pub fn generateMagicNumber() u64 {
    return getRandomNumberU64() & getRandomNumberU64() & getRandomNumberU64();
}
