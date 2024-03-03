// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import {NftRegistry} from "./../src/NftRegistry.sol";
import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

// mocks
import {EndpointV2Mock} from "./mocks/EndpointV2Mock.sol";

// SendParam
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";


abstract contract StateZero is Test {
    using stdStorage for StdStorage;

    NftRegistry public nftRegistry;
    EndpointV2Mock public lzMock;
    Router public router;

    address public userA;
    address public userB;
    address public owner;

    uint32 public dstEid;

    function setUp() public virtual {
        // users
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        owner = makeAddr("owner");

        // contracts

        vm.startPrank(owner);



        lzMock = new EndpointV2Mock();
        nftLocker = new NftLocker(address(lzMock), owner, address(nft));

        router = new Router(address(nft), address(nftLocker)); 

        // point Locker to router
        nftLocker.point(address(router));

        //setUp Oapp
        nftLocker.setPeer(dstEid, bytes32(uint256(uint160(address(1)))));

        vm.stopPrank();

        // mint to user
        vm.prank(userA);
        nft.mint(1);

        vm.prank(userB);
        nft.mint(2);

        vm.prank(userB);
        nft.mint(3);


    } 
}
