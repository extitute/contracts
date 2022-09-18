// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./ExtituteIssuers.sol";

error NotPeer();
error DuplicateSigner();

contract ExtituteBadges is ERC721, Ownable, AccessControl {
    bytes32 public constant TYPE_CREATOR_ROLE = keccak256("TYPE_CREATOR_ROLE");
    bytes32 public constant REVOCATION_ROLE = keccak256("REVOCATION_ROLE");
    string public contractURI; /*contractURI contract metadata json*/

    event BeginIssuance(
        uint256 badgeId,
        uint256 badgeType,
        address owner,
        address issuer,
        string messageUri
    );
    event Cosign(
        uint256 badgeId,
        uint256 badgeType,
        address owner,
        address cosigner,
        string messageUri
    );
    event Witness(
        uint256 badgeId,
        uint256 badgeType,
        address owner,
        address witness,
        string messageUri
    );
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
    event NewBadgeType(
        uint256 badgeType,
        uint256 reqCosigners,
        string name,
        string uri
    );

    struct BadgeConfig {
        string name;
        uint256 reqCosigners;
        string uri;
    }

    struct Badge {
        uint256 numCosigners;
        uint256 badgeType;
        address holder;
        uint256 numWitnesses;
        uint256 numFlags;
    }

    ExtituteIssuers public issuerContract;

    mapping(uint256 => BadgeConfig) public badgeConfigs;
    mapping(uint256 => Badge) internal badges;
    mapping(uint256 => mapping(address => bool)) public badgeCapabilities;
    mapping(uint256 => mapping(address => bool)) signers;

    uint256 public numBadgeConfigs;
    uint256 public numBadges;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory _contractURI,
        address _issuerContract
    ) ERC721(name_, symbol_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        issuerContract = ExtituteIssuers(_issuerContract);

        contractURI = _contractURI;
    }

    function createBadgeType(
        string memory _badgeName,
        uint256 _reqCosigners,
        string memory _badgeUri
    ) external onlyRole(TYPE_CREATOR_ROLE) {
        badgeConfigs[++numBadgeConfigs] = BadgeConfig(
            _badgeName,
            _reqCosigners,
            _badgeUri
        );
    }

    function updateBadgeType(
        uint256 _badgeType,
        string memory _badgeName,
        uint256 _reqCosigners,
        string memory _badgeUri
    ) external onlyRole(TYPE_CREATOR_ROLE) {
        badgeConfigs[_badgeType] = BadgeConfig(
            _badgeName,
            _reqCosigners,
            _badgeUri
        );
    }

    function issueBadge(
        uint256 _badgeType,
        address _recipient,
        string memory _messageUri
    ) external {
        if (_badgeType > numBadgeConfigs) revert InvalidBadgeType();
        if (
            !issuerContract.issuanceCapabilities(
                address(this),
                _badgeType,
                msg.sender
            )
        ) revert NotIssuer();

        badges[++numBadges] = Badge(0, _badgeType, _recipient, 0, 0);
        signers[numBadges][msg.sender] = true;

        if (badgeConfigs[_badgeType].reqCosigners == 0)
            _safeMint(_recipient, numBadges);

        emit BeginIssuance(
            numBadges,
            _badgeType,
            _recipient,
            msg.sender,
            _messageUri
        );
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

    function cosignBadge(
        uint256 _badgeId,
        address _recipient,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        if (badges[_badgeId].holder != _recipient) revert NotOwner();
        if (
            !issuerContract.issuanceCapabilities(
                address(this),
                _badgeType,
                msg.sender
            )
        ) revert NotIssuer();

        if (_exists(_badgeId)) revert AlreadyIssued();
        if (signers[_badgeId][msg.sender]) revert DuplicateSigner();

        badges[_badgeId].numCosigners++;
        signers[_badgeId][msg.sender] = true;

        if (
            badges[_badgeId].numCosigners >=
            badgeConfigs[_badgeType].reqCosigners
        ) _safeMint(_recipient, numBadges);

        emit Cosign(_badgeId, _badgeType, _recipient, msg.sender, _messageUri);
    }

    function witnessAsIssuer(
        uint256 _badgeId,
        address _owner,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        if (
            !issuerContract.issuanceCapabilities(
                address(this),
                _badgeType,
                msg.sender
            )
        ) revert NotIssuer();
        if (ownerOf(_badgeId) != _owner) revert NotOwner();

        badges[_badgeId].numWitnesses++;

        emit Witness(_badgeId, _badgeType, _owner, msg.sender, _messageUri);
    }

    function witnessAsPeer(
        uint256 _badgeId,
        address _owner,
        uint256 _witnessBadgeId,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        uint256 _witnessBadgeType = badges[_witnessBadgeId].badgeType;
        if (_badgeType != _witnessBadgeType) revert NotPeer();
        if (ownerOf(_witnessBadgeId) != msg.sender) revert NotOwner();
        if (ownerOf(_badgeId) != _owner) revert NotOwner();

        badges[_badgeId].numWitnesses++;

        emit Witness(_badgeId, _badgeType, _owner, msg.sender, _messageUri);
    }

    function flagBadgeAsIssuer(
        uint256 _badgeId,
        address _owner,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        if (
            !issuerContract.issuanceCapabilities(
                address(this),
                _badgeType,
                msg.sender
            )
        ) revert NotIssuer();
        if (ownerOf(_badgeId) != _owner) revert NotOwner();

        badges[_badgeId].numFlags++;

        emit Flag(_badgeId, _badgeType, _owner, msg.sender, _messageUri);
    }

    function flagBadgeAsPeer(
        uint256 _badgeId,
        address _owner,
        uint256 _flaggerBadgeId,
        string memory _messageUri
    ) external {
        uint256 _badgeType = badges[_badgeId].badgeType;
        uint256 _witnessBadgeType = badges[_flaggerBadgeId].badgeType;
        if (_badgeType != _witnessBadgeType) revert NotPeer();
        if (ownerOf(_flaggerBadgeId) != msg.sender) revert NotOwner();
        if (ownerOf(_badgeId) != _owner) revert NotOwner();

        badges[_badgeId].numFlags++;

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
        return badgeConfigs[_badgeType].uri;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal pure override {
        if ((from != address(0) && (to != address(0))))
            revert TransfersDisabled();
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
