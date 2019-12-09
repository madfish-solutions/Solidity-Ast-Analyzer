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

library Strings {

    // Key bytes.
    // http://www.unicode.org/versions/Unicode10.0.0/UnicodeStandard-10.0.pdf
    // Table 3-7, p 126, Well-Formed UTF-8 Byte Sequences

    // Default 80..BF range
    uint constant internal DL = 0x80;
    uint constant internal DH = 0xBF;

    // Row - number of bytes

    // R1 - 1
    uint constant internal B11L = 0x00;
    uint constant internal B11H = 0x7F;

    // R2 - 2
    uint constant internal B21L = 0xC2;
    uint constant internal B21H = 0xDF;

    // R3 - 3
    uint constant internal B31 = 0xE0;
    uint constant internal B32L = 0xA0;
    uint constant internal B32H = 0xBF;

    // R4 - 3
    uint constant internal B41L = 0xE1;
    uint constant internal B41H = 0xEC;

    // R5 - 3
    uint constant internal B51 = 0xED;
    uint constant internal B52L = 0x80;
    uint constant internal B52H = 0x9F;

    // R6 - 3
    uint constant internal B61L = 0xEE;
    uint constant internal B61H = 0xEF;

    // R7 - 4
    uint constant internal B71 = 0xF0;
    uint constant internal B72L = 0x90;
    uint constant internal B72H = 0xBF;

    // R8 - 4
    uint constant internal B81L = 0xF1;
    uint constant internal B81H = 0xF3;

    // R9 - 4
    uint constant internal B91 = 0xF4;
    uint constant internal B92L = 0x80;
    uint constant internal B92H = 0x8F;

    // Checks whether a string is valid UTF-8.
    // If the string is not valid, the function will throw.
    function validate(string memory self) internal pure {
        uint addr;
        uint len;
        assembly {
            addr := add(self, 0x20)
            len := mload(self)
        }
        if (len == 0) {
            return;
        }
        uint bytePos = 0;
        while (bytePos < len) {
            bytePos += parseRune(addr + bytePos);
        }
        require(bytePos == len);
    }

    // Parses a single character, or "rune" stored at address 'bytePos'
    // in memory.
    // Returns the length of the character in bytes.
    // solhint-disable-next-line code-complexity
    function parseRune(uint bytePos) internal pure returns (uint len) {
        uint val;
        assembly {
            val := mload(bytePos)
        }
        val >>= 224; // Remove all but the first four bytes.
        uint v0 = val >> 24; // Get first byte.
        if (v0 <= B11H) { // Check a 1 byte character.
            len = 1;
        } else if (B21L <= v0 && v0 <= B21H) { // Check a 2 byte character.
            var v1 = (val & 0x00FF0000) >> 16;
            require(DL <= v1 && v1 <= DH);
            len = 2;
        } else if (v0 == B31) { // Check a 3 byte character in the following three.
            validateWithNextDefault((val & 0x00FFFF00) >> 8, B32L, B32H);
            len = 3;
        } else if (v0 == B51) {
            validateWithNextDefault((val & 0x00FFFF00) >> 8, B52L, B52H);
            len = 3;
        } else if ((B41L <= v0 && v0 <= B41H) || v0 == B61L || v0 == B61H) {
            validateWithNextDefault((val & 0x00FFFF00) >> 8, DL, DH);
            len = 3;
        } else if (v0 == B71) { // Check a 4 byte character in the following three.
            validateWithNextTwoDefault(val & 0x00FFFFFF, B72L, B72H);
            len = 4;
        } else if (B81L <= v0 && v0 <= B81H) {
            validateWithNextTwoDefault(val & 0x00FFFFFF, DL, DH);
            len = 4;
        } else if (v0 == B91) {
            validateWithNextTwoDefault(val & 0x00FFFFFF, B92L, B92H);
            len = 4;
        } else { // If we reach this point, the character is not valid UTF-8
            revert();
        }
    }

    function validateWithNextDefault(uint val, uint low, uint high) private pure {
        uint b = (val & 0xFF00) >> 8;
        require(low <= b && b <= high);
        b = val & 0x00FF;
        require(DL <= b && b <= DH);
    }

    function validateWithNextTwoDefault(uint val, uint low, uint high) private pure {
        uint b = (val & 0xFF0000) >> 16;
        require(low <= b && b <= high);
        b = (val & 0x00FF00) >> 8;
        require(DL <= b && b <= DH);
        b = val & 0x0000FF;
        require(DL <= b && b <= DH);
    }

}

/* solhint-disable max-line-length */

contract StringsExamples {

    using Strings for string;

    function stringExampleValidateBrut() public pure {
        string memory str = "An preost wes on leoden, Laȝamon was ihoten He wes Leovenaðes sone -- liðe him be Drihten. He wonede at Ernleȝe at æðelen are chirechen, Uppen Sevarne staþe, sel þar him þuhte, Onfest Radestone, þer he bock radde.";
        str.validate();
    }

    function stringExampleValidateOdysseusElytis() public pure {
        string memory str = "Τη γλώσσα μου έδωσαν ελληνική το σπίτι φτωχικό στις αμμουδιές του Ομήρου. Μονάχη έγνοια η γλώσσα μου στις αμμουδιές του Ομήρου. από το Άξιον Εστί του Οδυσσέα Ελύτη";
        str.validate();
    }

    function stringExampleValidatePushkinsHorseman() public pure {
        string memory str = "На берегу пустынных волн Стоял он, дум великих полн, И вдаль глядел. Пред ним широко Река неслася; бедный чёлн По ней стремился одиноко. По мшистым, топким берегам Чернели избы здесь и там, Приют убогого чухонца; И лес, неведомый лучам В тумане спрятанного солнца, Кругом шумел.";
        str.validate();
    }

    function stringExampleValidateRunePoem() public pure {
        string memory str = "ᚠᛇᚻ᛫ᛒᛦᚦ᛫ᚠᚱᚩᚠᚢᚱ᛫ᚠᛁᚱᚪ᛫ᚷᛖᚻᚹᛦᛚᚳᚢᛗ ᛋᚳᛖᚪᛚ᛫ᚦᛖᚪᚻ᛫ᛗᚪᚾᚾᚪ᛫ᚷᛖᚻᚹᛦᛚᚳ᛫ᛗᛁᚳᛚᚢᚾ᛫ᚻᛦᛏ᛫ᛞᚫᛚᚪᚾ ᚷᛁᚠ᛫ᚻᛖ᛫ᚹᛁᛚᛖ᛫ᚠᚩᚱ᛫ᛞᚱᛁᚻᛏᚾᛖ᛫ᛞᚩᛗᛖᛋ᛫ᚻᛚᛇᛏᚪᚾ";
        str.validate();
    }

}
/* solhint-enable max-line-length */