// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SponsorNft} from "../../src/SponsorNft.sol";

contract TestSponsorNft is Test {
    SponsorNft sponsorNft;

    address owner;
    uint256 ownerPk;
    address account;
    uint256 accountPk;
    string tokenUri = "tokenUri";

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("owner");
        (account, accountPk) = makeAddrAndKey("account");
        sponsorNft = new SponsorNft(owner, "SponsorNft", "SPN");
    }

    function test_can_mint() public {
        vm.prank(owner);
        sponsorNft.mint(account, tokenUri);

        assertEq(sponsorNft.ownerOf(0), account);
        assertEq(sponsorNft.tokenURI(0), tokenUri);
    }

    function test_can_mintWithPermit() public {
        bytes32 hashedMessage = sponsorNft.getMessageHash(account, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, hashedMessage);

        vm.prank(account);
        sponsorNft.mintWithPermit(account, 0, tokenUri, hashedMessage, v, r, s);

        assertEq(sponsorNft.ownerOf(0), account);
        assertEq(sponsorNft.tokenURI(0), tokenUri);
    }

    function test_revert_mintWithPermit() public {
        bytes32 hashedMessage = sponsorNft.getMessageHash(account, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(accountPk, hashedMessage);

        vm.expectRevert(SponsorNft.SponsorNft__InvalidSignature.selector);
        vm.prank(account);
        sponsorNft.mintWithPermit(account, 0, tokenUri, hashedMessage, v, r, s);
    }
}
