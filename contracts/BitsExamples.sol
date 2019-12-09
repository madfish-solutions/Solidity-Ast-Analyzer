pragma solidity ^0.5.0;
pragma experimental "ABIEncoderV2";


library Bits {

    uint constant internal ONE = uint(1);
    uint constant internal ONES = uint(~0);

    // Sets the bit at the given 'index' in 'self' to '1'.
    // Returns the modified value.
    function setBit(uint self, uint8 index) internal pure returns (uint) {
        return self | ONE << index;
    }

    // Sets the bit at the given 'index' in 'self' to '0'.
    // Returns the modified value.
    function clearBit(uint self, uint8 index) internal pure returns (uint) {
        return self & ~(ONE << index);
    }

    // Sets the bit at the given 'index' in 'self' to:
    //  '1' - if the bit is '0'
    //  '0' - if the bit is '1'
    // Returns the modified value.
    function toggleBit(uint self, uint8 index) internal pure returns (uint) {
        return self ^ ONE << index;
    }

    // Get the value of the bit at the given 'index' in 'self'.
    function bit(uint self, uint8 index) internal pure returns (uint8) {
        return uint8(self >> index & 1);
    }

    // Check if the bit at the given 'index' in 'self' is set.
    // Returns:
    //  'true' - if the value of the bit is '1'
    //  'false' - if the value of the bit is '0'
    function bitSet(uint self, uint8 index) internal pure returns (bool) {
        return self >> index & 1 == 1;
    }

    // Checks if the bit at the given 'index' in 'self' is equal to the corresponding
    // bit in 'other'.
    // Returns:
    //  'true' - if both bits are '0' or both bits are '1'
    //  'false' - otherwise
    function bitEqual(uint self, uint other, uint8 index) internal pure returns (bool) {
        return (self ^ other) >> index & 1 == 0;
    }

    // Get the bitwise NOT of the bit at the given 'index' in 'self'.
    function bitNot(uint self, uint8 index) internal pure returns (uint8) {
        return uint8(1 - (self >> index & 1));
    }

    // Computes the bitwise AND of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitAnd(uint self, uint other, uint8 index) internal pure returns (uint8) {
        return uint8((self & other) >> index & 1);
    }

    // Computes the bitwise OR of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitOr(uint self, uint other, uint8 index) internal pure returns (uint8) {
        return uint8((self | other) >> index & 1);
    }

    // Computes the bitwise XOR of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitXor(uint self, uint other, uint8 index) internal pure returns (uint8) {
        return uint8((self ^ other) >> index & 1);
    }

    // Gets 'numBits' consecutive bits from 'self', starting from the bit at 'startIndex'.
    // Returns the bits as a 'uint'.
    // Requires that:
    //  - '0 < numBits <= 256'
    //  - 'startIndex < 256'
    //  - 'numBits + startIndex <= 256'
    function bits(uint self, uint8 startIndex, uint16 numBits) internal pure returns (uint) {
        require(0 < numBits && startIndex < 256 && startIndex + numBits <= 256);
        return self >> startIndex & ONES >> 256 - numBits;
    }

    // Computes the index of the highest bit set in 'self'.
    // Returns the highest bit set as an 'uint8'.
    // Requires that 'self != 0'.
    function highestBitSet(uint self) internal pure returns (uint8 highest) {
        require(self != 0);
        uint val = self;
        for (uint8 i = 128; i >= 1; i >>= 1) {
            if (val & (ONE << i) - 1 << i != 0) {
                highest += i;
                val >>= i;
            }
        }
    }

    // Computes the index of the lowest bit set in 'self'.
    // Returns the lowest bit set as an 'uint8'.
    // Requires that 'self != 0'.
    function lowestBitSet(uint self) internal pure returns (uint8 lowest) {
        require(self != 0);
        uint val = self;
        for (uint8 i = 128; i >= 1; i >>= 1) {
            if (val & (ONE << i) - 1 == 0) {
                lowest += i;
                val >>= i;
            }
        }
    }

}


contract BitsExamples {

    using Bits for uint;

    // Set bits
    function setBitExample() public pure {
        uint n = 0;
        n = n.setBit(0); // Set the 0th bit.
        assert(n == 1);  // 1
        n = n.setBit(1); // Set the 1st bit.
        assert(n == 3);  // 11
        n = n.setBit(2); // Set the 2nd bit.
        assert(n == 7);  // 111
        n = n.setBit(3); // Set the 3rd bit.
        assert(n == 15); // 1111

        // x.bit(y) == 1 => x.setBit(y) == x
        n = 1;
        assert(n.setBit(0) == n);
    }

    // Clear bits
    function clearBitExample() public pure {
        uint n = 15;       // 1111
        n = n.clearBit(0); // Clear the 0th bit.
        assert(n == 14);   // 1110
        n = n.clearBit(1); // Clear the 1st bit.
        assert(n == 12);   // 1100
        n = n.clearBit(2); // Clear the 2nd bit.
        assert(n == 8);    // 1000
        n = n.clearBit(3); // Clear the 3rd bit.
        assert(n == 0);    // 0

        // x.bit(y) == 0 => x.clearBit(y) == x
        n = 0;
        assert(n.clearBit(0) == n);
    }

    // Toggle bits
    function toggleBitExample() public pure {
        uint n = 9;         // 1001
        n = n.toggleBit(0); // Toggle the 0th bit.
        assert(n == 8);     // 1000
        n = n.toggleBit(1); // Toggle the 1st bit.
        assert(n == 10);    // 1010
        n = n.toggleBit(2); // Toggle the 2nd bit.
        assert(n == 14);    // 1110
        n = n.toggleBit(3); // Toggle the 3rd bit.
        assert(n == 6);     // 0110

        // x.toggleBit(y).toggleBit(y) == x (invertible)
        n = 55;
        assert(n.toggleBit(5).toggleBit(5) == n);
    }

    // Get an individual bit
    function bitExample() public pure {
        uint n = 9; // 1001
        assert(n.bit(0) == 1);
        assert(n.bit(1) == 0);
        assert(n.bit(2) == 0);
        assert(n.bit(3) == 1);
    }

    // Is a bit set
    function bitSetExample() public pure {
        uint n = 9; // 1001
        assert(n.bitSet(0) == true);
        assert(n.bitSet(1) == false);
        assert(n.bitSet(2) == false);
        assert(n.bitSet(3) == true);
    }

    // Are bits equal
    function bitEqualExample() public pure {
        uint n = 9; // 1001
        uint m = 3; // 0011
        assert(n.bitEqual(m, 0) == true);
        assert(n.bitEqual(m, 1) == false);
        assert(n.bitEqual(m, 2) == true);
        assert(n.bitEqual(m, 3) == false);
    }

    // Bit 'not'
    function bitNotExample() public pure {
        uint n = 9; // 1001
        assert(n.bitNot(0) == 0);
        assert(n.bitNot(1) == 1);
        assert(n.bitNot(2) == 1);
        assert(n.bitNot(3) == 0);

        // x.bit(y) = 1 - x.bitNot(y);
        assert(n.bitNot(0) == 1 - n.bit(0));
        assert(n.bitNot(1) == 1 - n.bit(1));
        assert(n.bitNot(2) == 1 - n.bit(2));
        assert(n.bitNot(3) == 1 - n.bit(3));
    }

    // Bits 'and'
    function bitAndExample() public pure {
        uint n = 9; // 1001
        uint m = 3; // 0011
        assert(n.bitAnd(m, 0) == 1);
        assert(n.bitAnd(m, 1) == 0);
        assert(n.bitAnd(m, 2) == 0);
        assert(n.bitAnd(m, 3) == 0);
    }

    // Bits 'or'
    function bitOrExample() public pure {
        uint n = 9; // 1001
        uint m = 3; // 0011
        assert(n.bitOr(m, 0) == 1);
        assert(n.bitOr(m, 1) == 1);
        assert(n.bitOr(m, 2) == 0);
        assert(n.bitOr(m, 3) == 1);
    }

    // Bits 'xor'
    function bitXorExample() public pure {
        uint n = 9; // 1001
        uint m = 3; // 0011
        assert(n.bitXor(m, 0) == 0);
        assert(n.bitXor(m, 1) == 1);
        assert(n.bitXor(m, 2) == 0);
        assert(n.bitXor(m, 3) == 1);
    }

    // Get bits
    function bitsExample() public pure {
        uint n = 13;                // 0 ... 01101
        assert(n.bits(0, 4) == 13); // 1101
        assert(n.bits(1, 4) == 6);  // 0110
        assert(n.bits(2, 4) == 3);  // 0011
        assert(n.bits(3, 4) == 1);  // 0001

        assert(n.bits(0, 4) == 13); // 1101
        assert(n.bits(0, 3) == 5);  // 101
        assert(n.bits(0, 2) == 1);  // 01
        assert(n.bits(0, 1) == 1);  // 1
    }

    function bitsExampleThatFails() public pure {
        uint n = 13;
        n.bits(2, 0); // There is no zero-bit uint!
    }

    // Highest bit set
    function highestBitSetExample() public pure {
        uint n = 13;                    // 0 ... 01101
        assert(n.highestBitSet() == 3); //        ^

    }

    // Highest bit set
    function lowestBitSetExample() public pure {
        uint n = 12;                    // 0 ... 01100
        assert(n.lowestBitSet() == 2);  //         ^

    }

}