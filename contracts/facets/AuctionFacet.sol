// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibFuncHelper} from "../libraries/LibFuncHelper.sol";
import "../interfaces/INFT.sol";
import "../interfaces/IERC165.sol";

contract AuctionFacet {
    LibAppStorage.Layout l;
    using LibFuncHelper for *;

    event StartAuction(uint256 indexed tokenId, uint256 indexed auctionId);
    event BidPlaced(uint256 indexed auctionId, uint256 amount);
    event AuctionSettled(uint256 indexed auctionId, bool indexed);

    // auction function which uses the verifyNFT function
    function startAuction(address nftContract, uint256 tokenId) public {
        require(verifyNFT(nftContract));
        require(INFT(nftContract).ownerOf(tokenId) == msg.sender, "NOT_OWNER");

        INFT(nftContract).transferFrom(msg.sender, address(this), tokenId);

        l.id = l.id + 1;
        LibAppStorage.Auction storage auc = l.auctionId[l.id];

        auc.owner = msg.sender;
        auc.nftId = tokenId;
        auc.nftContractAddress = nftContract;

        l.id++;

        emit StartAuction(tokenId, l.id);
    }

    function bid(
        uint256 _auctionId,
        uint256 _amount
    ) external returns (bool successful) {
        require(_amount > 0, "Zero Amount Is Not Enough Token To Bid");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "Purchase AUCToken To Bid");
        //transfer out tokens to contract
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        LibAppStorage.Auction storage auc = l.auctionId[_auctionId];
        require(!auc.isSettled, "NFT sold already, auction ended");

        auc.buyersBid = _amount;

        if (auc.highestBid == 0) {
            auc.highestBid = auc.buyersBid;
            auc.lastBidder = msg.sender;
        } else {
            require(
                _amount >
                    (auc.highestBid *
                        LibAppStorage.MID_BID_INCREAMENT_PERCENTAGE) /
                        100,
                "Bid amount must be at least 20% higher than the current bid"
            );
            uint percentageCut = LibFuncHelper.calculateIncentive(_amount);

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

    function endAuction(uint256 _auctionId) external {
        LibAppStorage.Auction storage auc = l.auctionId[_auctionId];
        require(msg.sender == auc.owner, "This is not your auction");
        auc.isSettled = true;

        INFT(auc.nftContractAddress).transferFrom(
            address(this),
            auc.lastBidder,
            auc.nftId
        );

        emit AuctionSettled(_auctionId, true);
    }

    function getAuction(
        uint _auctionId
    ) external view returns (LibAppStorage.Auction memory) {
        return l.auctionId[_auctionId];
    }

    // Function to verify if the NFT ID is compatible with ERC721 or ERC1155
    function verifyNFT(
        address nftContract
    ) internal view returns (bool isCompactible) {
        require(nftContract != address(0), "No zero address call");
        // Check ERC721 compatibility
        bytes4 erc721InterfaceId = 0x80ac58cd; // ERC721 interface ID
        bool isERC721 = IIERC165(nftContract).supportsInterface(
            erc721InterfaceId
        );

        // Check ERC1155 compatibility
        bytes4 erc1155InterfaceId = 0xd9b67a26; // ERC1155 interface ID
        bool isERC1155 = IIERC165(nftContract).supportsInterface(
            erc1155InterfaceId
        );

        // Either ERC721 or ERC1155 should be supported, but not both
        require(
            isERC721 || isERC1155,
            "NFT is neither ERC721 nor ERC1155 compatible"
        );

        isCompactible = true;
    }

    // Function to distribute the incentive according to the breakdown
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
            address(this),
            address(0x42AcD393442A1021f01C796A23901F3852e89Ff3), /// DAO
            toDAO
        );

        LibAppStorage._transferFrom(
            address(this),
            _outbidBidder, /// OUTBIDDER
            toOutbidBidder
        );

        LibAppStorage._transferFrom(
            address(this),
            address(0), /// TO Burn
            toTeam
        );

        LibAppStorage._transferFrom(
            address(this),
            address(0), /// TOTEAM
            toBurn
        );

        LibAppStorage._transferFrom(
            address(this),
            _lastERC20Interactor, /// TO LAST INTERACTOR
            toInteractor
        );
    }
}
