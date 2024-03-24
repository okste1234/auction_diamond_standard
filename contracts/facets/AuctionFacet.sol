// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

interface ERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract AuctionFacet {
    LibAppStorage.Layout l;

    uint256 id;
    uint256 public minBidIncrementPercentage = 20;
    uint256 totalFee;
    uint public burnedPercentage = 2;
    uint public daoPercentage = 2;
    uint public outbidPercentage = 3;
    uint public teamPercentage = 2;
    uint public lastInteractedPercentage = 1;

    struct Auction {
        address owner;
        uint256 nftId;
        uint256 buyersBid;
        uint256 highestBid;
        address lastBidder;
        bool isSettled;
    }

    mapping(uint256 => Auction) auctionId;

    event StartAuction(uint256 indexed tokenId, uint256 indexed auctionId);
    event BidPlaced(uint256 auctionId, uint256 amount);

    // auction function which uses the verifyNFT function
    function startAuction(address nftContract, uint256 tokenId) public {
        require(verifyNFT(nftContract));

        id = id + 1;
        Auction storage auc = auctionId[id];

        auc.owner = msg.sender;
        auc.nftId = tokenId;

        id++;

        emit StartAuction(tokenId, id);
    }

    function bid(
        uint256 _auctionId,
        uint256 _amount
    ) external returns (bool successful) {
        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");
        //transfer out tokens to contract
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        Auction storage auc = auctionId[_auctionId];
        require(!auc.isSettled, "NFT sold already");

        auc.buyersBid = _amount;

        l.lastERC20Interactor = msg.sender;

        if (auc.highestBid == 0) {
            auc.highestBid = auc.buyersBid;
            auc.lastBidder = msg.sender;
        } else {
            require(
                _amount > (auc.highestBid * minBidIncrementPercentage) / 100,
                "Bid amount must be at least 20% higher than the current bid"
            );
            uint percentageCut = calculateIncentive(_amount);

            distributeIncentive(
                percentageCut,
                auc.lastBidder,
                l.lastERC20Interactor,
                auc.highestBid
            );

            auc.lastBidder = msg.sender;
            auc.highestBid = _amount;
        }

        emit BidPlaced(_auctionId, _amount);

        successful = true;
    }

    function calculateIncentive(uint _amount) internal pure returns (uint) {
        return (10 * _amount) / 100;
    }

    // Function to distribute the tax according to the breakdown
    function distributeIncentive(
        uint _fee,
        address _outbidBidder,
        address _lastERC20Interactor,
        uint256 _formalBid
    ) internal {
        // Calculate each portion of the tax
        uint toBurn = (_fee * 20) / 100; // 2% burned
        uint toDAO = (_fee * 20) / 100; // 2% to DAO Wallet
        uint toOutbidBidder = _formalBid + ((_fee * 30) / 100); // 3% back to the outbid bidder
        uint toTeam = (_fee * 20) / 100; // 2% to Team Wallet
        uint toInteractor = (_fee * 10) / 100; // 1% to Interactor Wallet

        // Transfer the respective amounts to the specified wallets
        LibAppStorage._transferFrom(
            address(0),
            address(0x42AcD393442A1021f01C796A23901F3852e89Ff3), /// DAO
            toDAO
        );

        LibAppStorage._transferFrom(
            address(0),
            _outbidBidder, /// OUTBIDDER
            toOutbidBidder
        );

        LibAppStorage._transferFrom(
            address(0),
            address(0), /// TO Burn
            toTeam
        );

        LibAppStorage._transferFrom(
            address(0),
            address(0), /// TOTEAM
            toBurn
        );

        LibAppStorage._transferFrom(
            address(0),
            _lastERC20Interactor, /// TO LAST INTERACTOR
            toInteractor
        );
    }

    function endAuction() external returns (bool) {}

    // Function to verify if the NFT ID is compatible with ERC721 or ERC1155
    function verifyNFT(
        address nftContract
    ) internal view returns (bool isCompactible) {
        // Check ERC721 compatibility
        bytes4 erc721InterfaceId = 0x80ac58cd; // ERC721 interface ID
        bool isERC721 = ERC165(nftContract).supportsInterface(
            erc721InterfaceId
        );

        // Check ERC1155 compatibility
        bytes4 erc1155InterfaceId = 0xd9b67a26; // ERC1155 interface ID
        bool isERC1155 = ERC165(nftContract).supportsInterface(
            erc1155InterfaceId
        );

        // Either ERC721 or ERC1155 should be supported, but not both
        require(
            isERC721 || isERC1155,
            "NFT is neither ERC721 nor ERC1155 compatible"
        );

        isCompactible = true;
    }
}
