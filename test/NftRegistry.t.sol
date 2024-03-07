// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";

import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "node_modules/@openzeppelin/contracts/utils/Pausable.sol";

// mocks
import { MockRegistry } from "./mocks/MockRegistry.sol";
import { EndpointV2Mock } from "./mocks/EndpointV2Mock.sol";

// SendParam
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";


abstract contract StateZero is Test {
    using stdStorage for StdStorage;

    // contracts
    MockRegistry public registry;
    EndpointV2Mock public lzMock;
    address public dummyPool;

    // users
    address public userA;
    address public userB;
    address public owner;

    // params
    uint32 public dstEid;

    function setUp() public virtual {
        // users
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        owner = makeAddr("owner");

        // contracts
        vm.startPrank(owner);

        dummyPool = makeAddr("dummyPool");

        lzMock = new EndpointV2Mock();
        registry = new MockRegistry(address(lzMock), owner, dummyPool);

        //setUp Oapp
        registry.setPeer(dstEid, bytes32(uint256(uint160(address(1)))));
        registry.setPool(dummyPool);

        vm.stopPrank();

        // userA has 1 nft: tokenId = 0
        uint256[] memory tokenIdsA = new uint256[](1);
        tokenIdsA[0] = 0;
        registry.register(userA, tokenIdsA);

        // userB has 1 nft: tokenId = 1,2
        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;
        registry.register(userB, tokenIdsB);
    } 
}


contract StateZeroTest is StateZero {

    function testNftHoldings() public {

        (address owner1, ) = registry.nfts(0);
        assert(owner1 == userA);

        (address owner2, ) = registry.nfts(1);
        assert(owner2 == userB);

        (address owner3, ) = registry.nfts(2);
        assert(owner3 == userB);
    }

    function testUserCannotSetPool() public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        registry.setPool(userA);
    }

    function testOwnerCanSetPool() public {

        vm.prank(owner);
        registry.setPool(userA);

        assertEq(registry.pool(), userA);
    }

    function testUserCanRelease() public {
        // check prior
        (address owner2, ) = registry.nfts(1);
        assert(owner2 == userB);

        (address owner3, ) = registry.nfts(2);
        assert(owner3 == userB);


        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;

        vm.prank(userB);
        registry.release(tokenIdsB, dstEid, "");

        // check mapping after
        (owner2, ) = registry.nfts(1);
        (owner3, ) = registry.nfts(2);

        assertEq(owner2, address(0));
        assertEq(owner3, address(0));
    }

    function testPoolCanRecordStake() public {
        
        vm.prank(dummyPool);
        registry.recordStake(userB, 1, hex"01");

        // check mapping
        (address owner, bytes32 vaultId) = registry.nfts(1);
        assertEq(vaultId, hex"01");
        assertEq(owner, userB);

    }

    function testMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.expectRevert("Array max length exceeded");
        registry.release(tokenIds, dstEid, "");
    }

}

abstract contract StateStaked is StateZero {

    function setUp() public virtual override {
        super.setUp();

        // userB stakes into some vault
        vm.prank(dummyPool);
        registry.recordStake(userB, 1, hex"01");
    }
}


contract StateStakedTest is StateStaked {
     
    function testPoolCanRecordUnstake() public {
               
        vm.prank(dummyPool);
        registry.recordUnstake(userB, 1, hex"01");

        // check mapping
        (address owner, bytes32 vaultId) = registry.nfts(1);
        assertEq(vaultId, "");
        assertEq(owner, userB);
    }

    function testCannotReleaseWhenStaked() public {
        
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(userB);
        vm.expectRevert("Nft is staked");
        registry.release(tokenIds, dstEid, "");
    }

}