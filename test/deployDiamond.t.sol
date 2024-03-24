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

        A = mkaddr("staker a");
        B = mkaddr("staker b");
        C = mkaddr("staker c");

        //mint test tokens
        AUCTokenFacet(address(diamond)).mintTo(A);
        AUCTokenFacet(address(diamond)).mintTo(B);

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

    // function testRevertIfAuctionTimestampIsReachedOnBid() public {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 1e18, 2 days);
    //     vm.warp(3 days);
    //     vm.expectRevert("AUCTION_CLOSED");
    //     boundAuction.bid(0, 5e18);
    // }

    // function testRevertIfInsufficientTokenBalance() public {
    //     switchSigner(C);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 1e18, 2 days);
    //     vm.expectRevert("INSUFFICIENT_BALANCE");
    //     boundAuction.bid(0, 5e18);
    // }

    // function testRevertIfBidAmountIsLessThanAuctionStartPrice() public {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     vm.expectRevert("STARTING_PRICE_MUST_BE_GREATER");
    //     boundAuction.bid(0, 1e18);
    // }

    // function testRevertIfBidAmountIsLessThanLastBiddedAmount() public {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     boundAuction.bid(0, 2e18);
    //     vm.expectRevert("PRICE_MUST_BE_GREATER_THAN_LAST_BIDDED");
    //     boundAuction.bid(0, 1e18);
    // }

    // function testPercentageCut() public {
    //     uint oldOutbidderBal = boundERC.balanceOf(A);
    //     AUCTokenFacet(address(diamond)).mintTo(C);
    //     switchSigner(C);
    //     boundERC.transfer(address(0), 1e18);
    //     uint oldLastERC20InteractorBal = boundERC.balanceOf(
    //         boundERC.getLastGuy()
    //     );
    //     switchSigner(A);

    //     uint oldDaoBal = boundERC.balanceOf(
    //         0x42AcD393442A1021f01C796A23901F3852e89Ff3
    //     );
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     boundAuction.bid(0, 2e18);
    //     switchSigner(B);
    //     boundAuction.bid(0, 3e18);
    //     assertEq(
    //         boundERC.balanceOf(0x42AcD393442A1021f01C796A23901F3852e89Ff3),
    //         ((2 * 3e18) / 100) + oldDaoBal
    //     );
    //     assertEq(boundERC.balanceOf(A), ((3 * 3e18) / 100) + oldOutbidderBal);
    //     assertEq(boundERC.balanceOf(A), ((3 * 3e18) / 100) + oldOutbidderBal);
    //     assertEq(
    //         boundERC.balanceOf(boundERC.getLastGuy()),
    //         ((1 * 3e18) / 100) + oldLastERC20InteractorBal
    //     );
    // }

    // function testBids() public {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     boundAuction.bid(0, 2e18);
    //     switchSigner(B);
    //     boundAuction.bid(0, 3e18);
    //     LibAppStorage.Auction memory bids = boundAuction.getBid(1);
    //     assertEq(bids.length, 2);
    //     assertEq(bids[0].author, A);
    //     assertEq(bids[0].amount, 2e18);
    //     assertEq(bids[1].author, B);
    //     assertEq(bids[1].amount, (3e18 - ((10 * 3e18) / 100)));
    // }

    // function testRevertIfTimeNotReachedOnCloseBid() external {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     boundAuction.bid(0, 2e18);
    //     vm.expectRevert("TIME_NOT_REACHED");
    //     boundAuction.closeAuction(0);
    // }

    // function testRevertIfSignerHasNoRightOnCloseBid() external {
    //     switchSigner(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     boundAuction.bid(0, 2e18);
    //     switchSigner(B);
    //     vm.warp(2 days);
    //     vm.expectRevert("YOU_DONT_HAVE_RIGHT");
    //     boundAuction.closeAuction(0);
    // }

    // function testTokenTransferOnCloseBid() external {
    //     AUCTokenFacet(address(diamond)).mintTo(C);
    //     switchSigner(A);
    //     uint oldABalance = boundERC.balanceOf(A);
    //     erc721Token.mint();
    //     erc721Token.approve(address(diamond), 1);
    //     boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
    //     switchSigner(B);
    //     boundAuction.bid(0, 2e18);
    //     switchSigner(C);
    //     boundAuction.bid(0, 3e18);
    //     vm.warp(2 days);
    //     boundAuction.closeAuction(0);
    //     assertEq(
    //         boundERC.balanceOf(A),
    //         oldABalance + (3e18 - ((10 * 3e18) / 100))
    //     );
    // }

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
