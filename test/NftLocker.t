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
    }

    function testUserCannotCallUnlock() public {
        vm.prank(userB);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userB));

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        nftLocker.unlock(userB, tokenIds);
    }

    function testUserCannotCallSend() public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));

        nftLocker.send(dstEid, "", "");
    }

    function testUserCanLock() public {
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
         nftLocker.lock(tokenIds, dstEid, "");

        vm.stopPrank();

        // check assets
        assertEq(nft.balanceOf(userB), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 2);
        assert(nft.ownerOf(2) == address(nftLocker));
        assert(nft.ownerOf(3) == address(nftLocker));

        // check mapping
        assert(nftLocker.nfts(2) == userB);
        assert(nftLocker.nfts(3) == userB);
    }

    function testMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.prank(userB);
        vm.expectRevert("Array max length exceeded");
        nftLocker.lock(tokenIds, dstEid, "");
    
    }
}

// Note: userB locks both NFTs
abstract contract StateLocked is StateZero {

    function setUp() public virtual override {
        super.setUp();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
         nftLocker.lock(tokenIds, dstEid, "");

        vm.stopPrank();

        // check assets
        assertEq(nft.balanceOf(userB), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 2);
        assert(nft.ownerOf(2) == address(nftLocker));
        assert(nft.ownerOf(3) == address(nftLocker));

        // check mapping
        assert(nftLocker.nfts(2) == userB);
        assert(nftLocker.nfts(3) == userB);

    }
}

contract StateLockedTest is StateLocked {

    function testOwnerCanCallUnlock() public {
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.prank(owner);
        nftLocker.unlock(userB, tokenIds);


        // check assets
        assertEq(nft.balanceOf(userB), 2);
        assertEq(nft.balanceOf(address(nftLocker)), 0);
        assert(nft.ownerOf(2) == userB);
        assert(nft.ownerOf(3) == userB);

        // check mapping
        assert(nftLocker.nfts(2) == address(0));
        assert(nftLocker.nfts(3) == address(0));

    }


}


