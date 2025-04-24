// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library MerkleHelper {
    /// @notice Tạo Merkle Tree và trả về root + proof cho 1 leaf tại index
    /// @param accounts Danh sách người nhận
    /// @param amounts Danh sách số lượng tương ứng
    /// @param index Index leaf cần proof
    /// @return root Merkle root
    /// @return proof Merkle proof cho leaf tại index
    function createTreeAndProof(
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 index
    ) internal pure returns (bytes32 root, bytes32[] memory proof) {
        require(accounts.length == amounts.length, "MerkleHelper: length mismatch");
        require(index < accounts.length, "MerkleHelper: invalid index");

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            // Sử dụng cùng phương pháp tạo leaf như trong claimRefund
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encode(accounts[i], amounts[i]))));
        }

        root = computeMerkleRoot(leaves);
        proof = computeMerkleProof(leaves, index);
    }

    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "MerkleHelper: no leaves");

        while (leaves.length > 1) {
            uint256 nextLen = (leaves.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLen);

            for (uint256 i = 0; i < leaves.length; i += 2) {
                if (i + 1 < leaves.length) {
                    nextLevel[i / 2] = keccak256(abi.encodePacked(leaves[i], leaves[i + 1]));
                } else {
                    nextLevel[i / 2] = leaves[i]; // odd count, copy last
                }
            }

            leaves = nextLevel;
        }

        return leaves[0];
    }

    function computeMerkleProof(bytes32[] memory leaves, uint256 index)
        internal
        pure
        returns (bytes32[] memory proof)
    {
        require(index < leaves.length, "MerkleHelper: invalid index");

        uint256 totalLevels = log2ceil(leaves.length);
        proof = new bytes32[](totalLevels);
        uint256 proofPos = 0;

        while (leaves.length > 1) {
            uint256 pairIndex = index ^ 1;
            if (pairIndex < leaves.length) {
                proof[proofPos++] = leaves[pairIndex];
            }

            index /= 2;
            uint256 nextLen = (leaves.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLen);

            for (uint256 i = 0; i < leaves.length; i += 2) {
                if (i + 1 < leaves.length) {
                    nextLevel[i / 2] = keccak256(abi.encodePacked(leaves[i], leaves[i + 1]));
                } else {
                    nextLevel[i / 2] = leaves[i];
                }
            }

            leaves = nextLevel;
        }

        // Resize proof
        bytes32[] memory result = new bytes32[](proofPos);
        for (uint256 i = 0; i < proofPos; i++) {
            result[i] = proof[i];
        }
        return result;
    }

    function log2ceil(uint256 x) internal pure returns (uint256 y) {
        y = 0;
        uint256 v = 1;
        while (v < x) {
            v <<= 1;
            y++;
        }
    }
}
