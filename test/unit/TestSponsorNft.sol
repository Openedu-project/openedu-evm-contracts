// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SponsorNFT} from "src/SponsorNFT.sol";

contract TestSponsorNFT is Test {
    SponsorNFT sponsorNFT;

    address owner;
    uint256 ownerPk;
    address account;
    uint256 accountPk;
    string tokenUri = "tokenUri";

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("owner");
        (account, accountPk) = makeAddrAndKey("account");
        sponsorNFT = new SponsorNFT(owner, "SponsorNFT", "SPN");

        bool hasRoleAdmin = sponsorNFT.hasRole(sponsorNFT.DEFAULT_ADMIN_ROLE(), owner);
        assertTrue(hasRoleAdmin);

        vm.startPrank(owner);
        sponsorNFT.grantRole(sponsorNFT.MINTER_ROLE(), owner);
        vm.stopPrank();
    }

    function test_can_mint() public {
        vm.prank(owner);
        sponsorNFT.mint(account, tokenUri);

        assertEq(sponsorNFT.ownerOf(0), account);
        assertEq(sponsorNFT.tokenURI(0), tokenUri);
    }

    function test_can_mintWithPermit() public {
        bytes32 hashedMessage = sponsorNFT.getMessageHash(account, 0, 0, 1745196000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, hashedMessage);

        vm.prank(account);
        sponsorNFT.mintWithPermit(account, tokenUri, 0, 1745196000, v, r, s);

        assertEq(sponsorNFT.ownerOf(0), account);
        assertEq(sponsorNFT.tokenURI(0), tokenUri);
    }

    function test_revert_mintWithPermit() public {
        bytes32 hashedMessage = sponsorNFT.getMessageHash(account, 0, 0, 1745196000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(accountPk, hashedMessage);

        vm.expectRevert();
        vm.prank(account);
        sponsorNFT.mintWithPermit(account, tokenUri, 0, 1745196000, v, r, s);
    }
}
