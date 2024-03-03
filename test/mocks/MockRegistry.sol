// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NftRegistry} from "./../../src/NftRegistry.sol";

contract MockRegistry is NftRegistry {


    constructor(address endpoint, address owner, address pool_) NftRegistry(endpoint, owner, pool) {
    }
    
    function register(address user, uint256[] memory tokenIds) public {

        _register(user, tokenIds);
    }
}