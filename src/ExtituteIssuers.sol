// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import "./ExtituteBadges.sol";

error InvalidBadgeType();
error BadgeAlreadyExists();
error BadgeDoesNotExist();
error AlreadyIssued();
error DuplicateBadge();
error NotOwner();
error NotIssuer();
error NotIssuerOrPeer();
error TransfersDisabled();

contract ExtituteIssuers is ERC721, Ownable, AccessControl {
    bytes32 public constant TYPE_CREATOR_ROLE = keccak256("TYPE_CREATOR_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant REVOCATION_ROLE = keccak256("REVOCATION_ROLE");
    string public contractURI; /*contractURI contract metadata json*/

    struct Badge {
        address badgeContract;
        uint256 badgeType;
        address holder;
    }

    struct BadgeConfig {
        string name;
        bool exists;
        string uri;
    }

    event Flag(
        uint256 badgeId,
        uint256 badgeType,
        address owner,
        address flagger,
        string messageUri
    );
    event Revoke(
        uint256 badgeId,
        uint256 badgeType,
        address owner,
        address revoker,
        string messageUri
    );

    mapping(address => mapping(uint256 => BadgeConfig)) public badgeConfigs;
    mapping(uint256 => Badge) public badges;
    mapping(address => mapping(uint256 => mapping(address => bool)))
        public issuanceCapabilities;

    uint256 public numBadges;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory _contractURI
    ) ERC721(name_, symbol_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        contractURI = _contractURI;
    }

    function createBadgeType(
        string memory _badgeName,
        address _badgeContract,
        uint256 _badgeType,
        string memory _badgeUri
    ) external onlyRole(TYPE_CREATOR_ROLE) {
        if (_badgeType > ExtituteBadges(_badgeContract).numBadgeConfigs())
            revert InvalidBadgeType();
        if (badgeConfigs[_badgeContract][_badgeType].exists) revert BadgeAlreadyExists();
        badgeConfigs[_badgeContract][_badgeType] = BadgeConfig(
            _badgeName,
            true,
            _badgeUri
        );
    }
    
    function updateBadgeType(
        string memory _badgeName,
        address _badgeContract,
        uint256 _badgeType,
        string memory _badgeUri
    ) external onlyRole(TYPE_CREATOR_ROLE) {
        if (_badgeType > ExtituteBadges(_badgeContract).numBadgeConfigs())
            revert InvalidBadgeType();
        if (!badgeConfigs[_badgeContract][_badgeType].exists) revert InvalidBadgeType();
        badgeConfigs[_badgeContract][_badgeType] = BadgeConfig(
            _badgeName,
            true,
            _badgeUri
        );
    }

    function issueBadge(
        address _badgeContract,
        uint256 _badgeType,
        address _recipient
    ) external onlyRole(ISSUER_ROLE) {
        if (!badgeConfigs[_badgeContract][_badgeType].exists)
            revert InvalidBadgeType();

        if (issuanceCapabilities[_badgeContract][_badgeType][_recipient])
            revert DuplicateBadge();

        badges[++numBadges] = Badge(_badgeContract, _badgeType, _recipient);

        _safeMint(_recipient, numBadges);
    }

    function unequip(uint256 _badgeId) external {
        if (ownerOf(_badgeId) != msg.sender) revert NotOwner();

        _burn(_badgeId);
    }

    function revoke(uint256 _badgeId, string memory _messageUri)
        external
        onlyRole(REVOCATION_ROLE)
    {
        uint256 _badgeType = badges[_badgeId].badgeType;
        address _owner = ownerOf(_badgeId);
        _burn(_badgeId);
        emit Revoke(_badgeId, _badgeType, _owner, msg.sender, _messageUri);
    }

    function flagBadge(
        uint256 _badgeId,
        address _owner,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        address _badgeContract = badges[_badgeId].badgeContract;
        if (
            (!hasRole(ISSUER_ROLE, msg.sender)) &&
            (!issuanceCapabilities[_badgeContract][_badgeType][msg.sender])
        ) revert NotIssuerOrPeer();
        if (ownerOf(_badgeId) != _owner) revert NotOwner();

        emit Flag(_badgeId, _badgeType, _owner, msg.sender, _messageUri);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(tokenId);
        uint256 _badgeType = badges[tokenId].badgeType;
        address _badgeContract = badges[tokenId].badgeContract;
        return badgeConfigs[_badgeContract][_badgeType].uri;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if ((from != address(0) && (to != address(0))))
            revert TransfersDisabled();

        uint256 _badgeType = badges[tokenId].badgeType;
        address _badgeContract = badges[tokenId].badgeContract;

        if (from == address(0))
            issuanceCapabilities[_badgeContract][_badgeType][to] = true;
        if (to == address(0))
            issuanceCapabilities[_badgeContract][_badgeType][from] = false;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
