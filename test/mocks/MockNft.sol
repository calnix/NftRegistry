// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockERC721} from "./MockERC721.sol";

contract MockNft is MockERC721 {

    function mint(uint256 id) external {
        _mint(msg.sender, id);
    }
    
}