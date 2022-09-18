// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import "../src/ExtituteIssuers.sol";
import "../src/ExtituteBadges.sol";

contract ContractTest is Test {
    ExtituteIssuers issuers;
    ExtituteBadges badges;

    address contractOwner;
    address issuer1;
    address issuer2;
    address recipient1;
    address recipient2;

    bytes onlyOwnerMessage = bytes("Ownable: caller is not the owner");
    bytes invalidTokenIdMessage = bytes("ERC721: invalid token ID");

    function setUp() public {
        issuers = new ExtituteIssuers("Ext I", "EXTI", "ipfs://contracturi");
        badges = new ExtituteBadges(
            "Ext B",
            "EXTB",
            "ipfs://contracturi",
            address(issuers)
        );
        contractOwner = vm.addr(1);
        issuer1 = vm.addr(2);
        issuer2 = vm.addr(3);
        recipient1 = vm.addr(4);
        recipient2 = vm.addr(5);

        issuers.transferOwnership(contractOwner);
        issuers.grantRole(issuers.ISSUER_ROLE(), contractOwner);
        issuers.grantRole(issuers.TYPE_CREATOR_ROLE(), contractOwner);
        issuers.grantRole(issuers.REVOCATION_ROLE(), contractOwner);

        badges.transferOwnership(contractOwner);
        badges.grantRole(issuers.REVOCATION_ROLE(), contractOwner);
        badges.grantRole(issuers.TYPE_CREATOR_ROLE(), contractOwner);
    }

    function createBadgeTypeB() public {
        vm.startPrank(contractOwner);

        badges.createBadgeType("Badge Name", 1, "ipfs://badge");
        vm.stopPrank();
    }

    function createBadgeTypeI() public {
        vm.startPrank(contractOwner);

        issuers.createBadgeType(
            "Badge Name",
            address(badges),
            1,
            "ipfs://badge1"
        );
        vm.stopPrank();
    }

    function issueBadgeI(address _recipient) public {
        vm.startPrank(contractOwner);

        issuers.issueBadge(address(badges), 1, _recipient);

        vm.stopPrank();
    }

    function issueBadgeB(address _recipient) public {
        createBadgeTypeB();
        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, _recipient, "issue");

        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(1, _recipient, "cosign");
        vm.stopPrank();
    }

    function testExample() public {
        vm.startPrank(address(0xB0B));
        console2.log("Hello world!");
        assertTrue(true);
    }

    function testCreateBadgeTypeB() public {
        vm.startPrank(contractOwner);

        badges.createBadgeType("Badge Name", 1, "ipfs://badge");

        (string memory name, uint256 reqCosigners, string memory uri) = badges
            .badgeConfigs(1);

        assertEq(reqCosigners, 1);
        assertEq(name, "Badge Name");
        assertEq(uri, "ipfs://badge");
    }

    function testUpdateBadgeTypeB() public {
        vm.startPrank(contractOwner);

        badges.createBadgeType("Badge Name", 1, "ipfs://badge");
        badges.updateBadgeType(1, "New Badge Name", 1, "ipfs://badgeNew");

        (string memory name, uint256 reqCosigners, string memory uri) = badges
            .badgeConfigs(1);

        assertEq(reqCosigners, 1);
        assertEq(name, "New Badge Name");
        assertEq(uri, "ipfs://badgeNew");
    }

    function testCreateBadgeTypeI() public {
        createBadgeTypeB();

        vm.startPrank(contractOwner);

        issuers.createBadgeType(
            "Badge Name",
            address(badges),
            1,
            "ipfs://badge"
        );

        (string memory name, bool exists, string memory uri) = issuers
            .badgeConfigs(address(badges), 1);

        assertEq(exists, true);
        assertEq(name, "Badge Name");
        assertEq(uri, "ipfs://badge");
    }

    function testUpdateBadgeType() public {
        createBadgeTypeB();

        vm.startPrank(contractOwner);

        issuers.createBadgeType(
            "Badge Name",
            address(badges),
            1,
            "ipfs://badge"
        );

        issuers.updateBadgeType(
            "New Badge Name",
            address(badges),
            1,
            "ipfs://badgeNew"
        );

        (string memory name, bool exists, string memory uri) = issuers
            .badgeConfigs(address(badges), 1);

        assertEq(exists, true);
        assertEq(name, "New Badge Name");
        assertEq(uri, "ipfs://badgeNew");
    }

    function testCannotCreateBadgeIfNoCorrespondingBadge() public {
        vm.startPrank(contractOwner);

        vm.expectRevert(InvalidBadgeType.selector);
        issuers.createBadgeType(
            "Badge Name",
            address(badges),
            1,
            "ipfs://badge"
        );
    }

    function testIssueBadgeI() public {
        createBadgeTypeB();
        createBadgeTypeI();

        vm.startPrank(contractOwner);

        issuers.issueBadge(address(badges), 1, issuer1);

        (address badgeContract, uint256 badgeType, address holder) = issuers
            .badges(1);

        assertEq(issuers.ownerOf(1), issuer1);
        assertEq(badgeContract, address(badges));
        assertEq(badgeType, 1);
        assertEq(holder, issuer1);
        assertEq(issuers.tokenURI(1), "ipfs://badge1");
    }

    function testFailCannotIssueBadgeAsNotOwner() public {
        createBadgeTypeB();
        createBadgeTypeI();

        vm.startPrank(issuer1);

        issuers.issueBadge(address(badges), 1, issuer1);
    }

    // Unequip

    function testUnequip() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        assertEq(issuers.issuanceCapabilities(address(badges), 1, issuer1), true);

        vm.startPrank(issuer1);
        issuers.unequip(1);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);

        assertEq(issuers.issuanceCapabilities(address(badges), 1, issuer1), false);
    }

    function testCannotUnequipAsNotOwner() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        vm.startPrank(issuer2);

        vm.expectRevert(NotOwner.selector);
        issuers.unequip(1);
    }

    // Revoke
    function testRevoke(string memory revokeMessage) public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);
        assertEq(issuers.issuanceCapabilities(address(badges), 1, issuer1), true);

        vm.startPrank(contractOwner);
        issuers.revoke(1, revokeMessage);
        
        assertEq(issuers.issuanceCapabilities(address(badges), 1, issuer1), false);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);
    }

    function testFailCannotRevokeAsNotOwner() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        vm.startPrank(issuer2);

        issuers.revoke(1, "revoke");
    }

    // Flag
    function testFlag(string memory flagMessage) public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);
        issueBadgeI(issuer2);

        vm.startPrank(issuer2);
        issuers.flagBadge(1, issuer1, flagMessage);
    }

    function testFlagAsIssuer(string memory flagMessage) public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        vm.startPrank(contractOwner);
        issuers.flagBadge(1, issuer1, flagMessage);
    }

    function testCannotFlagIfWrongOwner() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);
        issueBadgeI(issuer2);

        vm.startPrank(issuer2);

        vm.expectRevert(NotOwner.selector);
        issuers.flagBadge(1, recipient1, "flagMessage");
    }

    function testCannotFlagIfDoesNotHoldPeerBadgeType() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        vm.startPrank(issuer2);

        vm.expectRevert(NotIssuerOrPeer.selector);
        issuers.flagBadge(1, issuer1, "flagMessage");
    }

    // No transfer
    function testCannotTransfer() public {
        createBadgeTypeB();
        createBadgeTypeI();
        issueBadgeI(issuer1);

        vm.startPrank(issuer1);

        vm.expectRevert(TransfersDisabled.selector);
        issuers.safeTransferFrom(issuer1, issuer2, 1);
    }

    function testCannotIssueInvalidBadgeType() public {
        createBadgeTypeB();
        createBadgeTypeI();

        vm.startPrank(contractOwner);

        vm.expectRevert(InvalidBadgeType.selector);
        issuers.issueBadge(address(badges), 2, issuer1);
    }

    function testIssueBadgeB(
        string memory issueMessage,
        string memory cosignMessage
    ) public {
        createBadgeTypeB();
        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, recipient1, issueMessage);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);

        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(1, recipient1, cosignMessage);
        assertEq(badges.ownerOf(1), recipient1);
        assertEq(badges.tokenURI(1), "ipfs://badge");
    }

    // Cannot co-sign self
    function testCannotCosignSelf(
        string memory issueMessage,
        string memory cosignMessage
    ) public {
        createBadgeTypeB();
        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, recipient1, issueMessage);

        vm.expectRevert(DuplicateSigner.selector);
        badges.cosignBadge(1, recipient1, cosignMessage);
    }

    function testCannotCosignAfterIssuance(
        string memory issueMessage,
        string memory cosignMessage
    ) public {
        createBadgeTypeB();
        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);
        issueBadgeI(recipient2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, recipient1, issueMessage);

        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(1, recipient1, cosignMessage);

        vm.stopPrank();

        vm.startPrank(recipient2);
        vm.expectRevert(AlreadyIssued.selector);
        badges.cosignBadge(1, recipient1, cosignMessage);
    }

    // Multiple co-signers
    function testIssueMoreCosigners(
        string memory issueMessage,
        string memory cosignMessage
    ) public {
        vm.startPrank(contractOwner);

        badges.createBadgeType("Badge Name", 2, "ipfs://badge");
        vm.stopPrank();

        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);
        issueBadgeI(recipient2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, recipient1, issueMessage);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);

        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(1, recipient1, cosignMessage);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);

        vm.stopPrank();

        vm.startPrank(recipient2);
        badges.cosignBadge(1, recipient1, cosignMessage);
        assertEq(badges.ownerOf(1), recipient1);
        assertEq(badges.tokenURI(1), "ipfs://badge");
    }

    // No co-signers
    function testIssueNoCosigners(string memory issueMessage) public {
        vm.startPrank(contractOwner);

        badges.createBadgeType("Badge Name", 0, "ipfs://badge");
        vm.stopPrank();

        createBadgeTypeI();

        issueBadgeI(issuer1);
        issueBadgeI(issuer2);
        issueBadgeI(recipient2);

        vm.startPrank(issuer1);

        badges.issueBadge(1, recipient1, issueMessage);

        assertEq(badges.ownerOf(1), recipient1);
        assertEq(badges.tokenURI(1), "ipfs://badge");
    }

    // Unequip
    function testUnequipBadgeB() public {
        issueBadgeB(recipient1);

        vm.startPrank(recipient1);
        badges.unequip(1);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);
    }

    function testCannotUnequipBadgeBAsNotOwner() public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer2);

        vm.expectRevert(NotOwner.selector);
        badges.unequip(1);
    }

    // Revoke
    function testRevokeBadgeB(string memory revokeMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(contractOwner);
        badges.revoke(1, revokeMessage);

        vm.expectRevert(invalidTokenIdMessage);
        badges.ownerOf(1);
    }

    function testFailCannotRevokeBadgeBAsNotOwner() public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer2);

        badges.revoke(1, "revoke");
    }

    // Witness as issuer
    function testWitnessBadgeBAsIssuer(string memory witnessMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer1);
        badges.witnessAsIssuer(1, recipient1, witnessMessage);
    }

    function testCannotWitnessAsIssuerIfNotIssuer(string memory witnessMessage)
        public
    {
        issueBadgeB(recipient1);

        vm.startPrank(recipient2);
        vm.expectRevert(NotIssuer.selector);
        badges.witnessAsIssuer(1, recipient1, witnessMessage);
    }

    // Witness as peer
    function testWitnessBadgeBAsPeer(string memory witnessMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer1);
        badges.issueBadge(1, recipient2, "issue");
        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(2, recipient2, "cosign");

        vm.stopPrank();
        vm.startPrank(recipient2);
        badges.witnessAsPeer(1, recipient1, 2, witnessMessage);
    }

    function testCannotWitnessAsPeerIfNotPeer(string memory witnessMessage)
        public
    {
        issueBadgeB(recipient1);

        vm.startPrank(recipient2);
        vm.expectRevert(NotPeer.selector);
        badges.witnessAsPeer(1, recipient1, 2, witnessMessage);
    }

    // Flag as issuer
    function testFlagBadgeBAsIssuer(string memory flagMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer1);
        badges.flagBadgeAsIssuer(1, recipient1, flagMessage);
    }

    function testCannotFlagAsIssuerIfNotIssuer(string memory flagMessage)
        public
    {
        issueBadgeB(recipient1);

        vm.startPrank(recipient2);
        vm.expectRevert(NotIssuer.selector);
        badges.flagBadgeAsIssuer(1, recipient1, flagMessage);
    }

    // Flag as peer
    function testFlagBadgeBAsPeer(string memory flagMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(issuer1);
        badges.issueBadge(1, recipient2, "issue");
        vm.stopPrank();

        vm.startPrank(issuer2);
        badges.cosignBadge(2, recipient2, "cosign");

        vm.stopPrank();
        vm.startPrank(recipient2);
        badges.flagBadgeAsPeer(1, recipient1, 2, flagMessage);
    }

    function testCannotFlagAsPeerIfNotPeer(string memory flagMessage) public {
        issueBadgeB(recipient1);

        vm.startPrank(recipient2);
        vm.expectRevert(NotPeer.selector);
        badges.flagBadgeAsPeer(1, recipient1, 2, flagMessage);
    }

    // No transfer
    function testCannotTransferBadgeB() public {
        issueBadgeB(recipient1);

        vm.startPrank(recipient1);

        vm.expectRevert(TransfersDisabled.selector);
        badges.safeTransferFrom(recipient1, recipient2, 1);
    }
}
