// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {EIP3009} from "./../lib/EIP3009.sol";
import {IERC20Internal} from "./../lib/IERC20Internal.sol";

contract MocaToken is EIP3009, Ownable {

    constructor(string memory name, string memory symbol, address owner) ERC20(name, symbol) Ownable(owner) {}


    // free mint baby
    function mint(uint256 amount) external {

        _mint(msg.sender, amount);
    }



}