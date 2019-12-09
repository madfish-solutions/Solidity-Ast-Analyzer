pragma solidity ^0.5.0;
pragma experimental "ABIEncoderV2";

library Memory {

    // Size of a word, in bytes.
    uint internal constant WORD_SIZE = 32;
    // Size of the header of a 'bytes' array.
    uint internal constant BYTES_HEADER_SIZE = 32;
    // Address of the free memory pointer.
    uint internal constant FREE_MEM_PTR = 0x40;

    // Compares the 'len' bytes starting at address 'addr' in memory with the 'len'
    // bytes starting at 'addr2'.
    // Returns 'true' if the bytes are the same, otherwise 'false'.
    function equals(uint addr, uint addr2, uint len) internal pure returns (bool equal) {
        assembly {
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }

    // Compares the 'len' bytes starting at address 'addr' in memory with the bytes stored in
    // 'bts'. It is allowed to set 'len' to a lower value then 'bts.length', in which case only
    // the first 'len' bytes will be compared.
    // Requires that 'bts.length >= len'
    function equals(uint addr, uint len, bytes memory bts) internal pure returns (bool equal) {
        require(bts.length >= len);
        uint addr2;
        assembly {
            addr2 := add(bts, /*BYTES_HEADER_SIZE*/32)
        }
        return equals(addr, addr2, len);
    }

    // Allocates 'numBytes' bytes in memory. This will prevent the Solidity compiler
    // from using this area of memory. It will also initialize the area by setting
    // each byte to '0'.
    function allocate(uint numBytes) internal pure returns (uint addr) {
        // Take the current value of the free memory pointer, and update.
        assembly {
            addr := mload(/*FREE_MEM_PTR*/0x40)
            mstore(/*FREE_MEM_PTR*/0x40, add(addr, numBytes))
        }
        uint words = (numBytes + WORD_SIZE - 1) / WORD_SIZE;
        for (uint i = 0; i < words; i++) {
            assembly {
                mstore(add(addr, mul(i, /*WORD_SIZE*/32)), 0)
            }
        }
    }

    // Copy 'len' bytes from memory address 'src', to address 'dest'.
    // This function does not check the or destination, it only copies
    // the bytes.
    function copy(uint src, uint dest, uint len) internal pure {
        // Copy word-length chunks while possible
        for (; len >= WORD_SIZE; len -= WORD_SIZE) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += WORD_SIZE;
            src += WORD_SIZE;
        }

        // Copy remaining bytes
        uint mask = 256 ** (WORD_SIZE - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    // Returns a memory pointer to the provided bytes array.
    function ptr(bytes memory bts) internal pure returns (uint addr) {
        assembly {
            addr := bts
        }
    }

    // Returns a memory pointer to the data portion of the provided bytes array.
    function dataPtr(bytes memory bts) internal pure returns (uint addr) {
        assembly {
            addr := add(bts, /*BYTES_HEADER_SIZE*/32)
        }
    }

    // This function does the same as 'dataPtr(bytes memory)', but will also return the
    // length of the provided bytes array.
    function fromBytes(bytes memory bts) internal pure returns (uint addr, uint len) {
        len = bts.length;
        assembly {
            addr := add(bts, /*BYTES_HEADER_SIZE*/32)
        }
    }

    // Creates a 'bytes memory' variable from the memory address 'addr', with the
    // length 'len'. The function will allocate new memory for the bytes array, and
    // the 'len bytes starting at 'addr' will be copied into that new memory.
    function toBytes(uint addr, uint len) internal pure returns (bytes memory bts) {
        bts = new bytes(len);
        uint btsptr;
        assembly {
            btsptr := add(bts, /*BYTES_HEADER_SIZE*/32)
        }
        copy(addr, btsptr, len);
    }

    // Get the word stored at memory address 'addr' as a 'uint'.
    function toUint(uint addr) internal pure returns (uint n) {
        assembly {
            n := mload(addr)
        }
    }

    // Get the word stored at memory address 'addr' as a 'bytes32'.
    function toBytes32(uint addr) internal pure returns (bytes32 bts) {
        assembly {
            bts := mload(addr)
        }
    }

    /*
    // Get the byte stored at memory address 'addr' as a 'byte'.
    function toByte(uint addr, uint8 index) internal pure returns (byte b) {
        require(index < WORD_SIZE);
        uint8 n;
        assembly {
            n := byte(index, mload(addr))
        }
        b = byte(n);
    }
    */
}


library Bytes {

    uint internal constant BYTES_HEADER_SIZE = 32;

    // Checks if two `bytes memory` variables are equal. This is done using hashing,
    // which is much more gas efficient then comparing each byte individually.
    // Equality means that:
    //  - 'self.length == other.length'
    //  - For 'n' in '[0, self.length)', 'self[n] == other[n]'
    function equals(bytes memory self, bytes memory other) internal pure returns (bool equal) {
        if (self.length != other.length) {
            return false;
        }
        uint addr;
        uint addr2;
        assembly {
            addr := add(self, /*BYTES_HEADER_SIZE*/32)
            addr2 := add(other, /*BYTES_HEADER_SIZE*/32)
        }
        equal = Memory.equals(addr, addr2, self.length);
    }

    // Checks if two 'bytes memory' variables points to the same bytes array.
    // Technically this is done by de-referencing the two arrays in inline assembly,
    // and checking if the values are the same.
    function equalsRef(bytes memory self, bytes memory other) internal pure returns (bool equal) {
        assembly {
            equal := eq(self, other)
        }
    }

    // Copies a byte array.
    // Returns the copied bytes.
    // The function works by creating a new bytes array in memory, with the
    // same length as 'self', then copying all the bytes from 'self' into
    // the new array.
    function copy(bytes memory self) internal pure returns (bytes memory) {
        if (self.length == 0) {
            return;
        }
        var addr = Memory.dataPtr(self);
        return Memory.toBytes(addr, self.length);
    }

    // Copies a section of 'self' into a new array, starting at the provided 'startIndex'.
    // Returns the new copy.
    // Requires that 'startIndex <= self.length'
    // The length of the substring is: 'self.length - startIndex'
    function substr(bytes memory self, uint startIndex) internal pure returns (bytes memory) {
        require(startIndex <= self.length);
        var len = self.length - startIndex;
        var addr = Memory.dataPtr(self);
        return Memory.toBytes(addr + startIndex, len);
    }

    // Copies 'len' bytes from 'self' into a new array, starting at the provided 'startIndex'.
    // Returns the new copy.
    // Requires that:
    //  - 'startIndex + len <= self.length'
    // The length of the substring is: 'len'
    function substr(bytes memory self, uint startIndex, uint len) internal pure returns (bytes memory) {
        require(startIndex + len <= self.length);
        if (len == 0) {
            return;
        }
        var addr = Memory.dataPtr(self);
        return Memory.toBytes(addr + startIndex, len);
    }

    // Combines 'self' and 'other' into a single array.
    // Returns the concatenated arrays:
    //  [self[0], self[1], ... , self[self.length - 1], other[0], other[1], ... , other[other.length - 1]]
    // The length of the new array is 'self.length + other.length'
    function concat(bytes memory self, bytes memory other) internal pure returns (bytes memory) {
        bytes memory ret = new bytes(self.length + other.length);
        var (src, srcLen) = Memory.fromBytes(self);
        var (src2, src2Len) = Memory.fromBytes(other);
        var (dest,) = Memory.fromBytes(ret);
        var dest2 = dest + srcLen;
        Memory.copy(src, dest, srcLen);
        Memory.copy(src2, dest2, src2Len);
        return ret;
    }

    // Copies a section of a 'bytes32' starting at the provided 'startIndex'.
    // Returns the copied bytes (padded to the right) as a new 'bytes32'.
    // Requires that 'startIndex < 32'
    function substr(bytes32 self, uint8 startIndex) internal pure returns (bytes32) {
        require(startIndex < 32);
        return bytes32(uint(self) << startIndex*8);
    }

    // Copies 'len' bytes from 'self' into a new array, starting at the provided 'startIndex'.
    // Returns the copied bytes (padded to the right) as a new 'bytes32'.
    // Requires that:
    //  - 'startIndex < 32'
    //  - 'startIndex + len <= 32'
    function substr(bytes32 self, uint8 startIndex, uint8 len) internal pure returns (bytes32) {
        require(startIndex < 32 && startIndex + len <= 32);
        return bytes32(uint(self) << startIndex*8 & ~uint(0) << (32 - len)*8);
    }

    // Copies 'self' into a new 'bytes memory'.
    // Returns the newly created 'bytes memory'
    // The returned bytes will be of length '32'.
    function toBytes(bytes32 self) internal pure returns (bytes memory bts) {
        bts = new bytes(32);
        assembly {
            mstore(add(bts, /*BYTES_HEADER_SIZE*/32), self)
        }
    }

    // Copies 'len' bytes from 'self' into a new 'bytes memory', starting at index '0'.
    // Returns the newly created 'bytes memory'
    // The returned bytes will be of length 'len'.
    function toBytes(bytes32 self, uint8 len) internal pure returns (bytes memory bts) {
        require(len <= 32);
        bts = new bytes(len);
        // Even though the bytes will allocate a full word, we don't want
        // any potential garbage bytes in there.
        uint data = uint(self) & ~uint(0) << (32 - len)*8;
        assembly {
            mstore(add(bts, /*BYTES_HEADER_SIZE*/32), data)
        }
    }

    // Copies 'self' into a new 'bytes memory'.
    // Returns the newly created 'bytes memory'
    // The returned bytes will be of length '20'.
    function toBytes(address self) internal pure returns (bytes memory bts) {
        bts = toBytes(bytes32(uint(self) << 96), 20);
    }

    // Copies 'self' into a new 'bytes memory'.
    // Returns the newly created 'bytes memory'
    // The returned bytes will be of length '32'.
    function toBytes(uint self) internal pure returns (bytes memory bts) {
        bts = toBytes(bytes32(self), 32);
    }

    // Copies 'self' into a new 'bytes memory'.
    // Returns the newly created 'bytes memory'
    // Requires that:
    //  - '8 <= bitsize <= 256'
    //  - 'bitsize % 8 == 0'
    // The returned bytes will be of length 'bitsize / 8'.
    function toBytes(uint self, uint16 bitsize) internal pure returns (bytes memory bts) {
        require(8 <= bitsize && bitsize <= 256 && bitsize % 8 == 0);
        self <<= 256 - bitsize;
        bts = toBytes(bytes32(self), uint8(bitsize / 8));
    }

    // Copies 'self' into a new 'bytes memory'.
    // Returns the newly created 'bytes memory'
    // The returned bytes will be of length '1', and:
    //  - 'bts[0] == 0 (if self == false)'
    //  - 'bts[0] == 1 (if self == true)'
    function toBytes(bool self) internal pure returns (bytes memory bts) {
        bts = new bytes(1);
        bts[0] = self ? byte(1) : byte(0);
    }

    // Computes the index of the highest byte set in 'self'.
    // Returns the index.
    // Requires that 'self != 0'
    // Uses big endian ordering (the most significant byte has index '0').
    function highestByteSet(bytes32 self) internal pure returns (uint8 highest) {
        highest = 31 - lowestByteSet(uint(self));
    }

    // Computes the index of the lowest byte set in 'self'.
    // Returns the index.
    // Requires that 'self != 0'
    // Uses big endian ordering (the most significant byte has index '0').
    function lowestByteSet(bytes32 self) internal pure returns (uint8 lowest) {
        lowest = 31 - highestByteSet(uint(self));
    }

    // Computes the index of the highest byte set in 'self'.
    // Returns the index.
    // Requires that 'self != 0'
    // Uses little endian ordering (the least significant byte has index '0').
    function highestByteSet(uint self) internal pure returns (uint8 highest) {
        require(self != 0);
        uint ret;
        if (self & 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000 != 0) {
            ret += 16;
            self >>= 128;
        }
        if (self & 0xffffffffffffffff0000000000000000 != 0) {
            ret += 8;
            self >>= 64;
        }
        if (self & 0xffffffff00000000 != 0) {
            ret += 4;
            self >>= 32;
        }
        if (self & 0xffff0000 != 0) {
            ret += 2;
            self >>= 16;
        }
        if (self & 0xff00 != 0) {
            ret += 1;
        }
        highest = uint8(ret);
    }

    // Computes the index of the lowest byte set in 'self'.
    // Returns the index.
    // Requires that 'self != 0'
    // Uses little endian ordering (the least significant byte has index '0').
    function lowestByteSet(uint self) internal pure returns (uint8 lowest) {
        require(self != 0);
        uint ret;
        if (self & 0xffffffffffffffffffffffffffffffff == 0) {
            ret += 16;
            self >>= 128;
        }
        if (self & 0xffffffffffffffff == 0) {
            ret += 8;
            self >>= 64;
        }
        if (self & 0xffffffff == 0) {
            ret += 4;
            self >>= 32;
        }
        if (self & 0xffff == 0) {
            ret += 2;
            self >>= 16;
        }
        if (self & 0xff == 0) {
            ret += 1;
        }
        lowest = uint8(ret);
    }

}

contract BytesExamples {

    using Bytes for *;

    // Check if bytes are equal.
    function bytesEqualsExample() public pure {
        bytes memory bts0 = hex"01020304";
        bytes memory bts1 = hex"01020304";
        bytes memory bts2 = hex"05060708";

        assert(bts0.equals(bts0)); // Check if a byte array equal to itself.
        assert(bts0.equals(bts1)); // Should be equal because they have the same byte at each position.
        assert(!bts0.equals(bts2)); // Should not be equal.
    }

    // Check reference equality
    function bytesEqualsRefExample() public pure {
        bytes memory bts0 = hex"01020304";
        bytes memory bts1 = bts0;

        // Every 'bytes' will satisfy 'equalsRef' with itself.
        assert(bts0.equalsRef(bts0));
        // Different variables, but bts0 was assigned to bts1, so they point to the same area in memory.
        assert(bts0.equalsRef(bts1));
        // Changing a byte in bts0 will also affect bts1.
        bts0[2] = 0x55;
        assert(bts1[2] == 0x55);

        bytes memory bts2 = hex"01020304";
        bytes memory bts3 = hex"01020304";

        // These bytes has the same byte at each pos (so they would pass 'equals'), but they are referencing different areas in memory.
        assert(!bts2.equalsRef(bts3));

        // Changing a byte in bts2 will not affect bts3.
        bts2[2] = 0x55;
        assert(bts3[2] != 0x55);
    }

    // copying
    function bytesCopyExample() public pure {
        bytes memory bts0 = hex"01020304";

        var bts0Copy0 = bts0.copy();

        // The individual bytes are the same.
        assert(bts0.equals(bts0Copy0));
        // bts0Copy is indeed a (n independent) copy.
        assert(!bts0.equalsRef(bts0Copy0));

        bytes memory bts1 = hex"0304";

        // Copy with start index.
        var bts0Copy1 = bts0.copy(2);

        assert(bts0Copy1.equals(bts1));

        bytes memory bts2 = hex"0203";

        // Copy with start index and length.
        var bts0Copy2 = bts0.copy(1, 2);

        assert(bts0Copy2.equals(bts2));
    }

    // concatenate
    function bytesConcatExample() public pure {
        bytes memory bts0 = hex"01020304";
        bytes memory bts1 = hex"05060708";

        bytes memory bts01 = hex"0102030405060708";

        var cct = bts0.concat(bts1);

        // Should be equal to bts01
        assert(cct.equals(bts01));
    }

    // find the highest byte set in a bytes32
    function bytes32HighestByteSetExample() public pure {
        bytes32 test0 = 0x01;
        bytes32 test1 = 0xbb00aa00;
        bytes32 test2 = "abc";

        // with bytesN, the highest byte is the least significant one.
        assert(test0.highestByteSet() == 31);
        assert(test1.highestByteSet() == 30); // aa
        assert(test2.highestByteSet() == 2);

        // Make sure that in the case of test2, the highest byte is equal to "c".
        assert(test2[test2.highestByteSet()] == 0x63);
    }

    // find the lowest byte set in a bytes32
    function bytes32LowestByteSetExample() public pure {
        bytes32 test0 = 0x01;
        bytes32 test1 = 0xbb00aa00;
        bytes32 test2 = "abc";

        // with bytesN, the lowest byte is the most significant one.
        assert(test0.lowestByteSet() == 31);
        assert(test1.lowestByteSet() == 28); // bb
        assert(test2.lowestByteSet() == 0);
    }

    // find the highest byte set in a uint
    function uintHighestByteSetExample() public pure {
        uint test0 = 0x01;
        uint test1 = 0xbb00aa00;

        // with uint, the highest byte is the most significant one.
        assert(test0.highestByteSet() == 0);
        assert(test1.highestByteSet() == 3);
    }

    // find the lowest byte set in a uint
    function uintLowestByteSetExample() public pure {
        uint test0 = 0x01;
        uint test1 = 0xbb00aa00;

        // with uint, the lowest byte is the least significant one.
        assert(test0.lowestByteSet() == 0);
        assert(test1.lowestByteSet() == 1);
    }

}