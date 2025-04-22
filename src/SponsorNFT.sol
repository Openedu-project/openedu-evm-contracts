// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SponsorNFT is ERC721, Ownable2Step, EIP712, ERC721URIStorage {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error SponsorNFT__InvalidSignature();
    error SponsorNFT__AlreadyMinted();
    error SponsorNFT__TokenNotFound();
    error SponsorNFT__SignatureExpired();
    error SponsorNFT__SignatureUsed();

    constructor(address initialOwner, string memory name, string memory symbol)
        Ownable(initialOwner)
        ERC721(name, symbol)
        EIP712(name, "1.0.0")
    {}

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event Minted(address indexed owner, uint256 indexed tokenId, string tokenUri);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    struct Approve {
        address account;
        uint256 tokenId;
        uint256 nonce;
        uint256 deadline;
        uint256 chainId;
    }

    bytes32 private constant MESSAGE_TYPEHASH =
        keccak256("Approve(address account,uint256 tokenId,uint256 nonce,uint256 deadline,uint256 chainId)");

    uint256 private s_tokenCounter;

    // Mapping to track used nonces
    mapping(bytes32 => bool) private s_usedNonces;

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function updateTokenUri(uint256 tokenId, string memory tokenUri) external onlyOwner {
        _requireOwned(tokenId);
        _setTokenURI(tokenId, tokenUri);
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mint(address account, string memory tokenUri) public onlyOwner {
        uint256 tokenId = s_tokenCounter;

        _setTokenURI(tokenId, tokenUri);
        _mint(account, tokenId);
        s_tokenCounter++;

        emit Minted(account, tokenId, tokenUri);
    }

    function mintWithPermit(
        address account,
        string memory tokenUri,
        uint256 nonce,
        uint256 deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        // Check if signature has expired
        if (block.timestamp > deadline) {
            revert SponsorNFT__SignatureExpired();
        }

        uint256 tokenId = s_tokenCounter;
        bytes32 digest = getMessageHash(account, tokenId, nonce, deadline);

        // Create a unique identifier for this signature by hashing the digest with the nonce
        bytes32 signatureId = keccak256(abi.encodePacked(digest, nonce));

        // Check if this signature has been used
        if (s_usedNonces[signatureId]) {
            revert SponsorNFT__SignatureUsed();
        }

        // Verify signature
        if (!_isValidSignature(owner(), digest, _v, _r, _s)) {
            revert SponsorNFT__InvalidSignature();
        }

        // Mark signature as used
        s_usedNonces[signatureId] = true;

        _setTokenURI(tokenId, tokenUri);
        _mint(account, tokenId);
        s_tokenCounter++;

        emit Minted(account, tokenId, tokenUri);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isValidSignature(address signer, bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        (
            address actualSigner,
            /*ECDSA.RecoverError recoverError*/
            ,
            /*bytes32 signatureLength*/
        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getMessageHash(address account, uint256 tokenId, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, account, tokenId, nonce, deadline, block.chainid)));
    }

    function tokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function isSignatureUsed(bytes32 signatureId) public view returns (bool) {
        return s_usedNonces[signatureId];
    }

    function getSignatureId(bytes32 digest, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(digest, nonce));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireOwned(tokenId);
        return super.tokenURI(tokenId);
    }
}
