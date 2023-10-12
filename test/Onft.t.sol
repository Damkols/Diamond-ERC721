// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
// import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ONFT.sol";
import "lib/solmate/src/tokens/ERC721.sol";
import "./helpers/DiamondUtils.sol";
import "./helpers/Helpers.sol";

contract MarketPlace is DiamondUtils, IDiamondCut, Helpers {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OurNFT nft;

    //public and private address of the users
    address userA;
    address userB;
    uint256 privKeyA;
    uint256 privKeyB;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet),"OurNFT","ONFT");
        dLoupe = new DiamondLoupeFacet();


        // Deploying the Alexia NFT contract and storing it's returning object
        nft = new OurNFT();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](2);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(nft),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OurNFT")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        (userA, privKeyA) = mkaddr("USERA");
        (userB, privKeyB) = mkaddr("USERB");


        nft.mint(userA, 1);
    }


    function testTokenName() public {
        assertEq(OurNFT(address(diamond)).name(), "OurNFT");
    }

    function testTokenSymbol() public {
        assertEq(OurNFT(address(diamond)).symbol(), "ONFT");
    }

    function testOwnerOf() public {
        nft.mint(userB, 2);
        assertEq(nft.ownerOf(2), userB);
    }

     function testBurn() public {
        nft.burn(1);
    }

    function testMint() public {
        nft.mint(userB, 3);
        assertEq(nft.ownerOf(3), userB);
    }

    function testSafemint() public {
        nft.safeMint(userB, 4);
        assertEq(nft.ownerOf(4), userB);
    }
    // function testSafeTransferFrom() public {
    //     nft.mint(userB, 5);
    //     nft._approve(userB, 5);
    //     nft._transferFrom(userB, userA, 5);
    //     assertEq(nft.ownerOf(5), userA);
    // }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
