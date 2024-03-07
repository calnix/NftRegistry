// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import { NftLocker } from "./../src/NftLocker.sol";
import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "node_modules/@openzeppelin/contracts/utils/Pausable.sol";

// errors
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

// mocks
import { MockNft } from "./mocks/MockNft.sol";
import { EndpointV2Mock } from "./mocks/EndpointV2Mock.sol";

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

    // events
    event NftLocked(address indexed user, uint256 indexed tokenId);
    event NftUnlocked(address indexed user, uint256 indexed tokenId);
    event Recovered(address indexed nft, uint256 indexed tokenId, address indexed receiver);
    event PoolFrozen(uint256 indexed timestamp);

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

    function testUserCannotCallExit() public {
        vm.prank(userB);
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
    
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        nftLocker.emergencyExit(tokenIds);
    }

    function testUserCannotCallFreeze() public {

        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));

        nftLocker.freeze();
    }

    function testMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.prank(userB);
        vm.expectRevert("Array max length exceeded");
        nftLocker.lock(tokenIds, dstEid, "");
    }

    function testUserCanLock() public {
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
                // check events
                 vm.expectEmit(true, true, false, false);
                emit NftLocked(userB, 2);

                vm.expectEmit(true, true, false, false);
                emit NftLocked(userB, 3);

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

// Note: userB locks both NFTs. Admin pauses thereafter.
abstract contract StateLockedAndPaused is StateZero {

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

        // admin pauses
        vm.prank(owner);
        nftLocker.pause();

    }
}

contract StateLockedAndPausedTest is StateLockedAndPaused {

    function testUserCannotLock() public {
        
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        nftLocker.lock(tokenIds, dstEid, "");
    }

    function testUserCannotCallExit() public {
        
        assertEq(nftLocker.isFrozen(), false);

        vm.prank(userB);
        vm.expectRevert("Locker not frozen");
    
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        nftLocker.emergencyExit(tokenIds);
    }

}


// Note: Admin pauses freezes locker
abstract contract StateFrozen is StateLockedAndPaused {

    function setUp() public virtual override {
        super.setUp();

        // admin freezes
        vm.prank(owner);
        nftLocker.freeze();
    }
}

contract StateFrozenTest is StateFrozen {

    function testUserCanExit() public {
        vm.prank(userB);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

            // check events
            vm.expectEmit(true, true, false, false);
            emit NftUnlocked(userB, 2);

            vm.expectEmit(true, true, false, false);
            emit NftUnlocked(userB, 3);

        nftLocker.emergencyExit(tokenIds);

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