// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import {Marketplace} from "../contracts/facets/Marketplace.sol";
import "../contracts/facets/ONFT.sol";
import "lib/solmate/src/tokens/ERC721.sol";
import {Order} from "../contracts/libraries/LibDiamond.sol";
import "./helpers/DiamondUtils.sol";
import "./helpers/Helpers.sol";

contract MarketPlace is DiamondUtils, IDiamondCut, Helpers {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    Marketplace mPlace;
    OurNFT nft;

    //OrerId starts at 0
    uint256 currentOrderId;

    //public and private address of the users
    address userA;
    address userB;
    uint256 privKeyA;
    uint256 privKeyB;

    //Instance of struct
    Order order;

    //signature used to authorise creation of lisiting
    bytes sig;


    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet),"OurNFT","ONFT");
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

         // Deploying the marketplace contract and storing it's returning object
        mPlace = new Marketplace();

        // Deploying the Alexia NFT contract and storing it's returning object
        nft = new OurNFT();

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
                facetAddress: address(nft),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OurNFT")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(mPlace),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("Marketplace")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        (userA, privKeyA) = mkaddr("USERA");
        (userB, privKeyB) = mkaddr("USERB");

        order = Order({
            token: address(nft),
            tokenId: 1,
            price: 1 ether,
            signature: bytes(""),
            deadline: 0,
            owner: userA,
            active: false
        });

        //storing the signature derived from the default listing
        sig = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );


        order.signature = sig;

        nft.mint(userA, 1);
    }


    function testTokenName() public {
        assertEq(OurNFT(address(diamond)).name(), "OurNFT");
    }

    
    function testOwnerCannotCreateOrder() public {
        order.owner = userB;
        switchSigner(userB);

        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.createOrder(order);
    }

    function testNFTNotApproved() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.NotApproved.selector);
        mPlace.createOrder(order);
    }

    function testMinPriceTooLow() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.price = 0;
        vm.expectRevert(Marketplace.MinPriceTooLow.selector);
        mPlace.createOrder(order);
    }

    function testMinDeadline() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        vm.expectRevert(Marketplace.DeadlineTooSoon.selector);
        mPlace.createOrder(order);
    }

    function testMinDuration() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(Marketplace.MinDurationNotMet.selector);
        mPlace.createOrder(order);
    }

    function testSignatureNotValid() public {
        // Test that signature is valid
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyB
        );
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mPlace.createOrder(order);
    }

    // EDIT Order
    function testEditNonValidOrder() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.OrderNotExistent.selector);
        mPlace.editOrder(1, 0, false);
    }

    function testEditOrderNotOwner() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        // vm.expectRevert(Marketplace.OrderNotExistent.selector);
        uint256 newOrderId = mPlace.createOrder(order);

        switchSigner(userB);
        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.editOrder(newOrderId, 0, false);
    }

    function testEditOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        mPlace.editOrder(newOrderId, 0.01 ether, false);

        Order memory _order = mPlace.getOrder(newOrderId);
        assertEq(_order.price, 0.01 ether);
        assertEq(_order.active, false);
    }

    // EXECUTE Order
    function testExecuteNonValidOrder() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.OrderNotExistent.selector);
        mPlace.executeOrder(1);
    }

    function testExecuteExpiredOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteOrderNotActive() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        mPlace.editOrder(newOrderId, 0.01 ether, false);
        switchSigner(userB);
        vm.expectRevert(Marketplace.OrderNotActive.selector);
        mPlace.executeOrder(newOrderId);
    }

    function testFulfilOrderPriceNotEqual() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceNotMet.selector,
                order.price - 0.9 ether
            )
        );
        mPlace.executeOrder{value: 0.9 ether}(newOrderId);
    }

    function testFulfilOrderPriceMismatch() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceMismatch.selector,
                order.price
            )
        );
        mPlace.executeOrder{value: 1.1 ether}(newOrderId);
    }

    function testFulfilOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        uint256 userABalanceBefore = userA.balance;

        mPlace.executeOrder{value: order.price}(newOrderId);

        uint256 userABalanceAfter = userA.balance;

        Order memory _order = mPlace.getOrder(newOrderId);
        assertEq(_order.price, 1 ether);
        assertEq(_order.active, false);

        assertEq(_order.active, false);
        assertEq(ERC721(order.token).ownerOf(order.tokenId), userB);
        assertEq(userABalanceAfter, userABalanceBefore + order.price);
    }


    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
