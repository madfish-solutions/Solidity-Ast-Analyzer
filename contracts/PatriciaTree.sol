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


/*
 * Data structures and utilities used in the Patricia Tree.
 *
 * More info at: https://github.com/chriseth/patricia-trie
 */
library Data {

    struct Label {
        bytes32 data;
        uint length;
    }

    struct Edge {
        bytes32 node;
        Label label;
    }

    struct Node {
        Edge[2] children;
    }

    struct Tree {
        bytes32 root;
        Data.Edge rootEdge;
        mapping(bytes32 => Data.Node) nodes;
    }

    // Returns a label containing the longest common prefix of `self` and `label`,
    // and a label consisting of the remaining part of `label`.
    function splitCommonPrefix(Label memory self, Label memory other) internal pure returns (
        Label memory prefix,
        Label memory labelSuffix
    ) {
        return splitAt(self, commonPrefix(self, other));
    }

    // Splits the label at the given position and returns prefix and suffix,
    // i.e. 'prefix.length == pos' and 'prefix.data . suffix.data == l.data'.
    function splitAt(Label memory self, uint pos) internal pure returns (Label memory prefix, Label memory suffix) {
        assert(pos <= self.length && pos <= 256);
        prefix.length = pos;
        if (pos == 0) {
            prefix.data = bytes32(0);
        } else {
            prefix.data = bytes32(uint(self.data) & ~uint(1) << 255 - pos);
        }
        suffix.length = self.length - pos;
        suffix.data = self.data << pos;
    }

    // Returns the length of the longest common prefix of the two labels.
    /*
    function commonPrefix(Label memory self, Label memory other) internal pure returns (uint prefix) {
        uint length = self.length < other.length ? self.length : other.length;
        // TODO: This could actually use a "highestBitSet" helper
        uint diff = uint(self.data ^ other.data);
        uint mask = uint(1) << 255;
        for (; prefix < length; prefix++) {
            if ((mask & diff) != 0) {
                break;
            }
            diff += diff;
        }
    }
    */

    function commonPrefix(Label memory self, Label memory other) internal pure returns (uint prefix) {
        uint length = self.length < other.length ? self.length : other.length;
        if (length == 0) {
            return 0;
        }
        uint diff = uint(self.data ^ other.data) & ~uint(0) << 256 - length; // TODO Mask should not be needed.
        if (diff == 0) {
            return length;
        }
        return 255 - Bits.highestBitSet(diff);
    }

    // Returns the result of removing a prefix of length `prefix` bits from the
    // given label (shifting its data to the left).
    function removePrefix(Label memory self, uint prefix) internal pure returns (Label memory r) {
        require(prefix <= self.length);
        r.length = self.length - prefix;
        r.data = self.data << prefix;
    }

    // Removes the first bit from a label and returns the bit and a
    // label containing the rest of the label (shifted to the left).
    function chopFirstBit(Label memory self) internal pure returns (uint firstBit, Label memory tail) {
        require(self.length > 0);
        return (uint(self.data >> 255), Label(self.data << 1, self.length - 1));
    }

    function edgeHash(Data.Edge memory self) internal pure returns (bytes32) {
        return keccak256(self.node, self.label.length, self.label.data);
    }

    // Returns the hash of the encoding of a node.
    function hash(Data.Node memory self) internal pure returns (bytes32) {
        return keccak256(edgeHash(self.children[0]), edgeHash(self.children[1]));
    }

    function insertNode(Data.Tree storage tree, Data.Node memory n) internal returns (bytes32 newHash) {
        bytes32 h = hash(n);
        tree.nodes[h].children[0] = n.children[0];
        tree.nodes[h].children[1] = n.children[1];
        return h;
    }

    function replaceNode(Data.Tree storage self, bytes32 oldHash, Data.Node memory n) internal returns (bytes32 newHash) {
        delete self.nodes[oldHash];
        return insertNode(self, n);
    }

    function insertAtEdge(Tree storage self, Edge e, Label key, bytes32 value) internal returns (Edge) {
        assert(key.length >= e.label.length);
        var (prefix, suffix) = splitCommonPrefix(key, e.label);
        bytes32 newNodeHash;
        if (suffix.length == 0) {
            // Full match with the key, update operation
            newNodeHash = value;
        } else if (prefix.length >= e.label.length) {
            // Partial match, just follow the path
            assert(suffix.length > 1);
            Node memory n = self.nodes[e.node];
            var (head, tail) = chopFirstBit(suffix);
            n.children[head] = insertAtEdge(self, n.children[head], tail, value);
            delete self.nodes[e.node];
            newNodeHash = insertNode(self, n);
        } else {
            // Mismatch, so let us create a new branch node.
            (head, tail) = chopFirstBit(suffix);
            Node memory branchNode;
            branchNode.children[head] = Edge(value, tail);
            branchNode.children[1 - head] = Edge(e.node, removePrefix(e.label, prefix.length + 1));
            newNodeHash = insertNode(self, branchNode);
        }
        return Edge(newNodeHash, prefix);
    }

    function insert(Tree storage self, bytes key, bytes value) internal {
        Label memory k = Label(keccak256(key), 256);
        bytes32 valueHash = keccak256(value);
        Edge memory e;
        if (self.root == 0) {
            // Empty Trie
            e.label = k;
            e.node = valueHash;
        } else {
            e = insertAtEdge(self, self.rootEdge, k, valueHash);
        }
        self.root = edgeHash(e);
        self.rootEdge = e;
    }
}

/*
 * Interface for patricia trees.
 *
 * More info at: https://github.com/chriseth/patricia-trie
 */
contract PatriciaTreeFace {
    function getRootHash() public view returns (bytes32);
    function getRootEdge() public view returns (Data.Edge e);
    function getNode(bytes32 hash) public view returns (Data.Node n);
    function getProof(bytes key) public view returns (uint branchMask, bytes32[] _siblings);
    function verifyProof(bytes32 rootHash, bytes key, bytes value, uint branchMask, bytes32[] siblings) public view returns (bool);
    function insert(bytes key, bytes value) public;
}

/*
 * Patricia tree implementation.
 *
 * More info at: https://github.com/chriseth/patricia-trie
 */
contract PatriciaTree is PatriciaTreeFace {

    using Data for Data.Tree;
    using Data for Data.Node;
    using Data for Data.Edge;
    using Data for Data.Label;
    using Bits for uint;

    Data.Tree internal tree;

    // Get the root hash.
    function getRootHash() public view returns (bytes32) {
        return tree.root;
    }

    // Get the root edge.
    function getRootEdge() public view returns (Data.Edge e) {
        e = tree.rootEdge;
    }

    // Get the node with the given key. The key needs to be
    // the keccak256 hash of the actual key.
    function getNode(bytes32 hash) public view returns (Data.Node n) {
        n = tree.nodes[hash];
    }

    // Returns the Merkle-proof for the given key
    // Proof format should be:
    //  - uint branchMask - bitmask with high bits at the positions in the key
    //                    where we have branch nodes (bit in key denotes direction)
    //  - bytes32[] _siblings - hashes of sibling edges
    function getProof(bytes key) public view returns (uint branchMask, bytes32[] _siblings) {
        require(tree.root != 0);
        Data.Label memory k = Data.Label(keccak256(key), 256);
        Data.Edge memory e = tree.rootEdge;
        bytes32[256] memory siblings;
        uint length;
        uint numSiblings;
        while (true) {
            var (prefix, suffix) = k.splitCommonPrefix(e.label);
            assert(prefix.length == e.label.length);
            if (suffix.length == 0) {
                // Found it
                break;
            }
            length += prefix.length;
            branchMask |= uint(1) << 255 - length;
            length += 1;
            var (head, tail) = suffix.chopFirstBit();
            siblings[numSiblings++] = tree.nodes[e.node].children[1 - head].edgeHash();
            e = tree.nodes[e.node].children[head];
            k = tail;
        }
        if (numSiblings > 0) {
            _siblings = new bytes32[](numSiblings);
            for (uint i = 0; i < numSiblings; i++) {
                _siblings[i] = siblings[i];
            }
        }
    }

    function verifyProof(bytes32 rootHash, bytes key, bytes value, uint branchMask, bytes32[] siblings) public view returns (bool) {
        Data.Label memory k = Data.Label(keccak256(key), 256);
        Data.Edge memory e;
        e.node = keccak256(value);
        for (uint i = 0; branchMask != 0; i++) {
            uint bitSet = branchMask.lowestBitSet();
            branchMask &= ~(uint(1) << bitSet);
            (k, e.label) = k.splitAt(255 - bitSet);
            uint bit;
            (bit, e.label) = e.label.chopFirstBit();
            bytes32[2] memory edgeHashes;
            edgeHashes[bit] = e.edgeHash();
            edgeHashes[1 - bit] = siblings[siblings.length - i - 1];
            e.node = keccak256(edgeHashes);
        }
        e.label = k;
        require(rootHash == e.edgeHash());
        return true;
    }

    function insert(bytes key, bytes value) public {
        tree.insert(key, value);
    }

}