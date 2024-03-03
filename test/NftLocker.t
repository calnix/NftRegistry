// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import {NftLocker} from "./../src/NftLocker.sol";
import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

// errors
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

// mocks
import {MockNft} from "./mocks/MockNft.sol";
import {EndpointV2Mock} from "./mocks/EndpointV2Mock.sol";

// SendParam
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract StateZero is Test {
    using stdStorage for StdStorage;

    MockNft public nft;
    NftLocker public nftLocker;
    EndpointV2Mock public lzMock;

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

        nft = new MockNft();
        nft.initialize("mockNft", "mockNft");

        lzMock = new EndpointV2Mock();
        nftLocker = new NftLocker(address(lzMock), owner, address(nft));

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


contract StateZeroTest is StateZero {

    function testLockerSetup() public {
        assert(address(nftLocker.MOCA_NFT()) == address(nft));
        assert(nftLocker.router() == address(router));
    }

    function testRouterSetup() public {

        assert(address(router.MOCA_NFT()) == address(nft));
        assert(address(router.NFT_LOCKER()) == address(nftLocker));
    }

    function testUserCannotCallLock() public {
        
        vm.prank(userA);
        vm.expectRevert(NftLocker.IncorrectCaller.selector);

        bytes memory nullBytes = new bytes(0);
        nftLocker.lock(userA, 1, 11, nullBytes);
    }

    function testUserCannotCallPoint() public {

        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));

        nftLocker.point(userA);
    }

    function testUserCannotCallUnlock() public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));

        nftLocker.unlock(userB, 2);
    }

    function testUserCannotCallSend() public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));

        bytes memory nullBytes = new bytes(0);

        nftLocker.send(11, 1, nullBytes, userA);
    }


    function testOwnerCanCallLock() public {

        vm.prank(userA);
        nft.approve(address(nftLocker), 1);

        vm.prank(owner);
        
        nftLocker.lock(userA, 1, dstEid, "");
        
        // check assets
        assertEq(nft.balanceOf(userA), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 1);
        assert(nft.ownerOf(1) == address(nftLocker));

        // check mapping
        assert(nftLocker.tokenIds(1) == userA);
    }

    function testRouterCanCallLock() public {
        vm.prank(userA);
        nft.approve(address(nftLocker), 1);
        
        vm.prank(address(router));
        
        nftLocker.lock(userA, 1, dstEid, "");

        // check assets
        assertEq(nft.balanceOf(userA), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 1);
        assert(nft.ownerOf(1) == address(nftLocker));

        // check mapping
        assert(nftLocker.tokenIds(1) == userA);
    }

    function testUserCanInteractThroughRouter() public {

        bytes memory payload1 = abi.encodeWithSignature("lock(uint256,uint32,bytes)", 2, dstEid, "");
        bytes memory payload2 = abi.encodeWithSignature("lock(uint256,uint32,bytes)", 3, dstEid, "");

        bytes[] memory allCalls = new bytes[](2);
        allCalls[0] = payload1;
        allCalls[1] = payload2;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
        
        vm.stopPrank();

        // check assets
        assertEq(nft.balanceOf(userB), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 2);
        assert(nft.ownerOf(2) == address(nftLocker));
        assert(nft.ownerOf(3) == address(nftLocker));

        // check mapping
        assert(nftLocker.tokenIds(2) == userB);
        assert(nftLocker.tokenIds(3) == userB);

    }


}

// Note: userB locks both NFTs
abstract contract StateLocked is StateZero {

    function setUp() public virtual override {
        super.setUp();


        bytes memory payload1 = abi.encodeWithSignature("lock(uint256,uint32,bytes)", 2, dstEid, "");
        bytes memory payload2 = abi.encodeWithSignature("lock(uint256,uint32,bytes)", 3, dstEid, "");

        bytes[] memory allCalls = new bytes[](2);
        allCalls[0] = payload1;
        allCalls[1] = payload2;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
         router.batch(allCalls);
        
        vm.stopPrank();

        // check assets
        assertEq(nft.balanceOf(userB), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 2);
        assert(nft.ownerOf(2) == address(nftLocker));
        assert(nft.ownerOf(3) == address(nftLocker));

        // check mapping
        assert(nftLocker.tokenIds(2) == userB);
        assert(nftLocker.tokenIds(3) == userB);

    }
}

contract StateLockedTest is StateLocked {

    function testOwnerCanCallUnlock() public {
        
        vm.prank(owner);
        nftLocker.unlock(userB, 2);

        // check assets
        assertEq(nft.balanceOf(userB), 1);
        assert(nft.ownerOf(2) == userB);

        // check mapping
        assert(nftLocker.tokenIds(2) == address(0));
    }


}


