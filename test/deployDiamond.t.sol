// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";

import "../contracts/facets/AUCTokenFacet.sol";

import "../contracts/facets/AuctionFacet.sol";

import "../contracts/NFTToken.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibAppStorage.sol";

contract DiamondDeployer is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUCTokenFacet erc20Facet;
    AuctionFacet aFacet;
    NFTToken erc721Token;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);
    address D = address(0xd);

    AuctionFacet boundAuction;
    AUCTokenFacet boundERC;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new AUCTokenFacet();
        aFacet = new AuctionFacet();
        erc721Token = new NFTToken();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(aFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AuctionFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(erc20Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUCTokenFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        A = mkaddr("bidder a");
        B = mkaddr("bidder b");
        C = mkaddr("bidder c");
        D = mkaddr("bidder D");

        //mint test tokens
        AUCTokenFacet(address(diamond)).mintTo(A);
        AUCTokenFacet(address(diamond)).mintTo(B);
        AUCTokenFacet(address(diamond)).mintTo(D);

        boundAuction = AuctionFacet(address(diamond));
        boundERC = AUCTokenFacet(address(diamond));
    }

    function testRevertIfTokenAddressIsZero() public {
        vm.expectRevert("No zero address call");
        boundAuction.startAuction(address(0), 1);
    }

    function testRevertIfNotTokenOwner() public {
        switchSigner(A);
        erc721Token.mint();
        switchSigner(B);
        vm.expectRevert("NOT_OWNER");
        boundAuction.startAuction(address(erc721Token), 1);
    }

    function testRevertIfTokenTypeIsNotERC721orERC1155() public {
        switchSigner(A);
        // erc721Token.mint();
        vm.expectRevert();
        boundAuction.startAuction(address(erc20Facet), 1);
    }

    function testAuctionStateChange() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);
        LibAppStorage.Auction memory auc = boundAuction.getAuction(1);
        assertEq(auc.nftId, 1);
        assertEq(auc.owner, A);
        assertEq(auc.isSettled, false);
        assertEq(auc.nftContractAddress, address(erc721Token));
    }

    function testRevertIfBidderDoNotHaveEnoughToken() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);

        switchSigner(C);
        vm.expectRevert("Purchase AUCToken To Bid");
        boundAuction.bid(1, 20e18);
    }

    function testRevertIfBidAmountIsZero() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);
        switchSigner(B);
        vm.expectRevert("Zero Amount Is Not Enough Token To Bid");
        boundAuction.bid(1, 0);
    }

    function testFirstBid() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);

        switchSigner(B);
        boundAuction.bid(1, 20e18);
        LibAppStorage.Auction memory auc = boundAuction.getAuction(1);

        assertEq(auc.buyersBid, 20e18);
        assertEq(auc.highestBid, auc.buyersBid);
    }

    function testPercentageCut() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);

        switchSigner(B);
        uint oldOutbidderBal = boundERC.balanceOf(B);

        boundAuction.bid(1, 20e18);

        switchSigner(D);
        boundAuction.bid(1, 30e18);
        assertEq(oldOutbidderBal + ((3 * 30e18) / 100), boundERC.balanceOf(B));
    }

    function testBids() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);
        boundAuction.bid(1, 20e18);
        switchSigner(B);
        boundAuction.bid(1, 30e18);
        LibAppStorage.Auction memory auc = boundAuction.getAuction(1);
        assertEq(auc.highestBid, 30e18);
        assertEq(auc.lastBidder, address(B));
    }

    function testSuccessfulTransferOfNFT() external {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);
        boundAuction.bid(1, 20e18);
        LibAppStorage.Auction memory auc = boundAuction.getAuction(1);
        assertEq(auc.lastBidder, address(A));
        boundAuction.endAuction(1);
    }

    function testRevertIfTriedToBidOnCloseBid() external {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(address(erc721Token), 1);
        boundAuction.bid(1, 20e18);
        switchSigner(B);
        boundAuction.bid(1, 30e18);
        LibAppStorage.Auction memory auc = boundAuction.getAuction(1);
        assertEq(auc.lastBidder, address(B));
        switchSigner(A);
        boundAuction.endAuction(1);
        vm.expectRevert("NFT sold already, auction ended");
        switchSigner(D);
        boundAuction.bid(1, 30e18);
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
