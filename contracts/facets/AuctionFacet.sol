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

    struct Auction {
        address owner;
        uint256 nftId;
        uint256 buyersBid;
        uint256 highestBid;
        address[] bidders;
        bool isSettled;
    }

    mapping(uint256 => Auction) auctionId;

    event StartAuction(uint256 indexed tokenId, uint256 indexed auctionId);

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

    function bid(uint256 _auctionId, uint256 _amount) external returns (bool) {
        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");
        //transfer out tokens to contract
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        Auction storage auc = auctionId[_auctionId];
        auc.buyersBid = _amount;
        auc.bidders.push(msg.sender);
        auc.highestBid = auc.highestBid < _amount ? _amount : auc.highestBid;
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
