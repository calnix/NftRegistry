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
import { OAppSender, Origin } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

abstract contract StateZero is Test {
    using stdStorage for StdStorage;

    MockNft public nft;
    NftLocker public nftLocker;
    EndpointV2Mock public lzMock;

    address public userA;
    address public userB;
    address public userC;
    address public owner;

    uint32 public dstEid = 1;

    // events
    event NftLocked(address indexed user, uint256[] indexed tokenIds);
    event NftUnlocked(address indexed user, uint256[] indexed tokenIds);
    event Recovered(address indexed nft, uint256 indexed tokenId, address indexed receiver);
    event PoolFrozen(uint256 indexed timestamp);

    function setUp() public virtual {
        // users
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        userC = makeAddr("userC");
        owner = makeAddr("owner");

        // contracts

        vm.startPrank(owner);

        nft = new MockNft();
        nft.initialize("mockNft", "mockNft");

        lzMock = new EndpointV2Mock();
        nftLocker = new NftLocker(address(lzMock), owner, address(nft), dstEid);
        vm.label(address(nftLocker), "locker");

        //setUp Oapp
        nftLocker.setPeer(dstEid, bytes32(uint256(uint160(address(1)))));

        vm.stopPrank();

        // mint to user
        vm.prank(userA);
        nft.mint(1);

        vm.startPrank(userB);
            nft.mint(2);
            nft.mint(3);
        vm.stopPrank();


        vm.startPrank(userC);
            nft.mint(4);
            nft.mint(5);
            nft.mint(6);
            nft.mint(7);
            nft.mint(8);
        vm.stopPrank();

        //deal gas
        vm.deal(userA, 1 ether);
        vm.deal(userB, 1 ether);
        vm.deal(userC, 1 ether);

    } 
}

contract StateZeroTest is StateZero {

    function testLockerSetup() public {
        assert(address(nftLocker.MOCA_NFT()) == address(nft));
    }

    function testUserCannotTransferOwnership() public {
        
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        nftLocker.transferOwnership(userA);
    }

    function testOwnerTransferOwnership() public {
        vm.prank(owner);
        nftLocker.transferOwnership(userA);

        // check pending owner
        assert(nftLocker.pendingOwner() == userA);

        // accept ownership
        vm.prank(userA);
        nftLocker.acceptOwnership();

        assert(nftLocker.owner() == userA);
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

    function testCannotExceedMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.prank(userB);
        vm.expectRevert("Array max length exceeded");
        nftLocker.lock{value: 78_550}(tokenIds);
    }

    function testCannotDuplicateTokenId() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 2;

        vm.startPrank(userB);
        nft.setApprovalForAll(address(nftLocker), true);
        vm.expectRevert("Already locked");
        nftLocker.lock{value: 78_550}(tokenIds);

        vm.stopPrank();
    }

    function testUserCanLock() public {
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.startPrank(userB);
         nft.setApprovalForAll(address(nftLocker), true);
                // check events
                 vm.expectEmit(true, true, false, false);
                emit NftLocked(userB, tokenIds);

         nftLocker.lock{value: 78_550}(tokenIds);

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
         nftLocker.lock{value: 78_550}(tokenIds);

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

        nftLocker.lock{value: 78_550}(tokenIds);
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

    function testUserCannotLock() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 2;

        vm.startPrank(userB);
            nft.setApprovalForAll(address(nftLocker), true);
            vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
            nftLocker.lock{value: 78_550}(tokenIds);

        vm.stopPrank();
    }

    function testUserCanExit() public {
        vm.prank(userB);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

            // check event
            vm.expectEmit(true, true, false, false);
            emit NftUnlocked(userB, tokenIds);

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

abstract contract GasProfiling is StateZero {

    function setUp() public virtual override {
        super.setUp();

        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 4;
            tokenIds[1] = 5;
            tokenIds[2] = 6;
            tokenIds[3] = 7;
            tokenIds[4] = 8;

        vm.startPrank(userC);
         nft.setApprovalForAll(address(nftLocker), true);
         nftLocker.lock{value: 158_350}(tokenIds);

        vm.stopPrank();

        // check assets
        assertEq(nft.balanceOf(userC), 0);
        assertEq(nft.balanceOf(address(nftLocker)), 5);
        assert(nft.ownerOf(4) == address(nftLocker));
        assert(nft.ownerOf(5) == address(nftLocker));
        assert(nft.ownerOf(6) == address(nftLocker));
        assert(nft.ownerOf(7) == address(nftLocker));
        assert(nft.ownerOf(8) == address(nftLocker));

        // check mapping
        assert(nftLocker.nfts(4) == userC);
        assert(nftLocker.nfts(5) == userC);
        assert(nftLocker.nfts(6) == userC);
        assert(nftLocker.nfts(7) == userC);
        assert(nftLocker.nfts(8) == userC);
    }
}


contract GasProfilingTest is GasProfiling {

    //Note: calling Locker::lzReceive::_unlock
    //      gas profiling to define options on NftRegistry::release
    function testGasUsed(uint64 nonce, bytes32 guid, address executor) public {
        // setup
        bytes32 addressAsBytes = bytes32(uint256(uint160(address(nftLocker))));
        uint32 eid = 1;

        vm.prank(address(owner));
        nftLocker.setPeer(eid, addressAsBytes);

        //lzReceive params
        Origin memory _origin = Origin({srcEid: eid, sender: addressAsBytes, nonce: nonce});
        bytes32 _guid = guid;
        address _executor = executor;
        bytes memory _extraData = "";
        
        // userB tokenIds
        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 4;
            tokenIds[1] = 5;
            tokenIds[2] = 6;
            tokenIds[3] = 7;
            tokenIds[4] = 8;

        bytes memory payload = abi.encode(userC, tokenIds);
        
        // call
        vm.prank(address(lzMock));

        //Note: gasleft requires “2 gas” to execute
        uint256 initialGas = gasleft();
        nftLocker.lzReceive(_origin, _guid, payload, _executor, _extraData);
        uint256 finalGas = gasleft();

        uint256 gasUsed = initialGas - finalGas;
        console2.log("gasUsed", gasUsed);
    }

}

/**
calling lzReceive::_unlock :

#1: calc via gasLeft(): tokenIds[](1);
 gasUsed = 50986
 gas_opde = 4
 base = 22k
 total = 50,986 + 4 + 22,000 = 72,990

#2: calc via gasLeft(): tokenIds[](2);
 gasUsed = 69389
 gas_opde = 4
 base = 22k
 total = 69,389 + 4 + 22,000 = 91,393

#3: calc via gasLeft(): tokenIds[](3);
 gasUsed = 87791
 gas_opde = 4
 base = 22k
 total = 87,791 + 4 + 22,000 = 109,795

#4: calc via gasLeft(): tokenIds[](4);
 gasUsed = 106192
 gas_opde = 4
 base = 22k
 total = 106,192 + 4 + 22,000 = 128,196

#5: calc via gasLeft(): tokenIds[](5);
 gasUsed = 124595
 gas_opde = 4
 base = 22k
 total = 124,595 + 4 + 22,000 = 146,599

gas increments by ~18,403 per additional tokenid/loop 


calculating via  --gas-report:

    | Function Name                        | min             | avg    | median | max    | # calls |
    | lock                                 | 24298           | 129453 | 148269 | 263378 | 7       |
    | lzReceive                            | 120040          | 120436 | 120628 | 120712 | 256     |
*/