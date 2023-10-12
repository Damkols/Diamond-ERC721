// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/tokens/ERC721.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ERC721Facet} from "./ERC721.sol";

contract OurNFT is ERC721Facet {

    function name() public view virtual returns(string memory){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds._name;
    }
    function symbol() public view virtual returns(string memory){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds._symbol;
    }
    function tokenURI(
        uint256 id
    ) public view virtual override returns (string memory) {
        return "base-marketplace";
    }

    function mint(address recipient, uint256 tokenId) public payable {
        _mint(recipient, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function _balanceOf(address owner) public view virtual returns (uint256) {
       return balanceOf(owner);
    }

    function _ownerOf(uint256 id) public view virtual returns (address owner) {
       return ownerOf(id);
    }

    function safeMint(address to, uint256 id) public virtual {
        _safeMint(to, id);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        safeTransferFrom(from, to, id);
    }

    function _transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);
    }

    function _setApprovalForAll(address operator, bool approved) public virtual {
        setApprovalForAll(operator, approved);
    }

    function _approve(address spender, uint256 id) public virtual {
        approve(spender, id);
    }

}