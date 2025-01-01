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

const bitboard = @import("bitboard.zig");

fn getRandomNumberU32() u32 {
    var number: u32 = bitboard.state;

    number ^= number << 13;
    number ^= number >> 17;
    number ^= number << 5;

    bitboard.state = number;

    return number;
}

//from Tord Ramstad's Article on Generating Magic Numbers
fn getRandomNumberU64() u64 {
    const n1: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n2: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n3: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;
    const n4: u64 = @as(u64, getRandomNumberU32()) & 0xFFFF;

    return n1 | (n2 << 16) | (n3 << 32) | (n4 << 48);
}

fn generateMagicNumber() u64 {
    return getRandomNumberU64() & getRandomNumberU64() & getRandomNumberU64();
}

pub fn findMagicNumber(square: u6, relevantBits: u6, attackMask: u64) u64 { 
    var occupancies: u64[4096] = undefined;
    var attacks: u64[4096] = undefined;
    var usedAttacks: u64[4096] = undefined;

}
