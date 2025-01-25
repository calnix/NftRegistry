// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";

import {Ownable} from "./../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "./../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

// mocks
import { MockRegistry } from "./mocks/MockRegistry.sol";
import { EndpointV2Mock } from "./mocks/EndpointV2Mock.sol";

// SendParam
import "@layerzerolabs/oft-evm/contracts/oft/interfaces/IOFT.sol";

import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OAppSender, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

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
    uint32 public dstEid = 1;

    // tokenIds per user
    uint256[] public tokenIdsA;
    uint256[] public tokenIdsB;

    // events
    event PoolUpdated(address indexed newPool);
    event LockerUpdated(address indexed newLocker);

    event NftRegistered(address indexed user, uint256[] indexed tokenIds);
    event NftReleased(address indexed user, uint256[] indexed tokenIds);

    event NftStaked(address indexed user, uint256[] indexed tokenIds, bytes32 indexed vaultId);
    event NftUnstaked(address indexed user, uint256[] indexed tokenIds, bytes32 indexed vaultId);

    function setUp() public virtual {
        // users
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        owner = makeAddr("owner");

        // contracts
        vm.startPrank(owner);

        dummyPool = makeAddr("dummyPool");

        lzMock = new EndpointV2Mock();
        registry = new MockRegistry(address(lzMock), owner, dummyPool, dstEid);
        vm.label(address(registry), "registry");

        //setUp Oapp
        registry.setPeer(dstEid, bytes32(uint256(uint160(address(1)))));
        registry.setPool(dummyPool);

        vm.stopPrank();

        // gas
        vm.deal(userA, 1 ether);
        vm.deal(userB, 1 ether);

        // tokenId arrays
        tokenIdsA.push(0);
        tokenIdsB.push(1);
        tokenIdsB.push(2);
        
        registry.register(userA, tokenIdsA);
        registry.register(userB, tokenIdsB);

    } 
}


contract StateZeroTest is StateZero {
    
    function testUserCannotSetGasBuffer(uint256 amount) public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        registry.setGasBuffer(amount);
    }

    function testUserCannotTransferOwnership() public {
        
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        registry.transferOwnership(userA);
    }

    function testOwnerTransferOwnership() public {
        vm.prank(owner);
        registry.transferOwnership(userA);

        // check pending owner
        assert(registry.pendingOwner() == userA);

        // accept ownership
        vm.prank(userA);
        registry.acceptOwnership();

        assert(registry.owner() == userA);
    }

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
        
        vm.expectEmit(true, false, false, false);
        emit PoolUpdated(address(1));

        registry.setPool(address(1));

        assertEq(registry.pool(), address(1));
    }

    function testOwnerSetGasBuffer(uint256 amount) public {
        assertEq(registry.gasBuffer(), 0);

        vm.prank(owner);
        registry.setGasBuffer(amount);

        assertEq(registry.gasBuffer(), amount);
    }

    function testCannotExceedReleaseMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.expectRevert("Array max length exceeded");
        registry.release{value: 1 ether}(tokenIds);
    }

    function testCannotReleaseRepeatedTokenIds() public {    

        vm.expectRevert("Not Owner");
        registry.release{value: 91_403}(tokenIdsB);
    }

    function testCannotReleaseOtherTokenId() public {
        
        vm.prank(userA);
        vm.expectRevert("Not Owner");
        registry.release{value: 91_403}(tokenIdsB);
    }

    function testCannotReleaseRevertsInsufficientGas() public {

        vm.prank(userB);
        vm.expectRevert(abi.encodeWithSelector(OAppSender.NotEnoughNative.selector, 0));
        registry.release(tokenIdsB);
    }

    function testUserCanRelease() public {
        // check prior
        (address owner2, ) = registry.nfts(1);
        assert(owner2 == userB);

        (address owner3, ) = registry.nfts(2);
        assert(owner3 == userB);

        vm.prank(userB);

            vm.expectEmit(true, true, false, false);
            emit NftReleased(userB, tokenIdsB);

        registry.release{value: 91_403}(tokenIdsB);

        // check mapping after
        (owner2, ) = registry.nfts(1);
        (owner3, ) = registry.nfts(2);

        assertEq(owner2, address(0));
        assertEq(owner3, address(0));
    }

    function testUserCannotRecordStake() public {

        vm.prank(userA);
        vm.expectRevert("Only pool");
        registry.recordStake(userA, tokenIdsA, hex"01");
    }

    function testPoolCanRecordStake() public {
    
        vm.prank(dummyPool);

            vm.expectEmit(true, true, false, false);
            emit NftStaked(userA, tokenIdsA, hex"01");
        
        registry.recordStake(userA, tokenIdsA, hex"01");

        // check mapping
        (address owner, bytes32 vaultId) = registry.nfts(0);
        assertEq(vaultId, hex"01");
        assertEq(owner, userA);
    }

    function testPoolCanRecordMultipleStake() public {

        vm.prank(dummyPool);

            vm.expectEmit(true, true, false, false);
            emit NftStaked(userB, tokenIdsB, hex"02");

        registry.recordStake(userB, tokenIdsB, hex"02");

        // check mapping
        (address owner1, bytes32 vaultId1) = registry.nfts(1);
        assertEq(vaultId1, hex"02");
        assertEq(owner1, userB);

        // check mapping
        (address owner2, bytes32 vaultId2) = registry.nfts(2);
        assertEq(vaultId2, hex"02");
        assertEq(owner2, userB);
    }

}

abstract contract StateStaked is StateZero {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(dummyPool);
            registry.recordStake(userA, tokenIdsA, hex"01");
            registry.recordStake(userB, tokenIdsB, hex"02");
        vm.stopPrank();
    }
}


contract StateStakedTest is StateStaked {
     
    function testCannotReleaseWhenStaked() public {

        vm.prank(userB);
        vm.expectRevert("Nft is staked");
        registry.release{value: 73_000}(tokenIdsB);
    }

    function testIncorrectUserRecordUnstake() public {

        vm.prank(dummyPool);
        vm.expectRevert("Incorrect tokenId");
        registry.recordUnstake(userA, tokenIdsB, hex"01");
    }

    function testUserCannotRecordUnstake() public {

        vm.prank(userB);
        vm.expectRevert("Only pool");
        registry.recordUnstake(userB, tokenIdsB, hex"02");
    }

    function testPoolCanRecordUnstake() public {

        vm.prank(dummyPool);

            vm.expectEmit(true, true, false, false);
            emit NftUnstaked(userA, tokenIdsA, hex"01");

        registry.recordUnstake(userA, tokenIdsA, hex"01");

        // check mapping
        (address owner, bytes32 vaultId) = registry.nfts(0);
        assertEq(vaultId, "");
        assertEq(owner, userA);
    }

    function testPoolCanRecordUnstakeMultiple() public {
           
        vm.prank(dummyPool);
        
            vm.expectEmit(true, true, false, false);
            emit NftUnstaked(userB, tokenIdsB, hex"02");

        registry.recordUnstake(userB, tokenIdsB, hex"02");

        // check mapping
        (address owner1, bytes32 vaultId1) = registry.nfts(1);
        assertEq(vaultId1, "");
        assertEq(owner1, userB);

        // check mapping
        (address owner2, bytes32 vaultId2) = registry.nfts(2);
        assertEq(vaultId2, "");
        assertEq(owner2, userB);
    }

    //Note: calling Registry::lzReceive::_register 
    //      gas profiling for options on NftLocker::lock
    function testGasUsed(uint64 nonce, bytes32 guid, address executor) public {
        // setup
        bytes32 addressAsBytes = bytes32(uint256(uint160(address(registry))));
        uint32 eid = 1;

        Origin memory _origin = Origin({srcEid: eid, sender: addressAsBytes, nonce: nonce});
        vm.prank(address(owner));
        registry.setPeer(eid, addressAsBytes);

        bytes32 _guid = guid;
        address _executor = executor;
        bytes memory _extraData = "";
        
        // unused tokenIds
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 8;
        tokenIds[1] = 888;
        tokenIds[2] = 1414;
        tokenIds[3] = 88188;
        //tokenIds[4] = 7;

        bytes memory payload = abi.encode(msg.sender, tokenIds);
        
        // call
        vm.prank(address(lzMock));

        //Note: gasleft requires “2 gas” to execute
        uint256 initialGas = gasleft();
        registry.lzReceive(_origin, _guid, payload, _executor, _extraData);
        uint256 finalGas = gasleft();

        uint256 gasUsed = initialGas - finalGas;
        console2.log("gasUsed", gasUsed);
    }
}

/**
calling lzReceive::_register :

#1: calc via gasLeft(): tokenIds[](1);
 gasUsed = 29937
 gas_opde = 4
 base = 22k
 total = 29,937 + 4 + 22,000 = 51,941

#2: calc via gasLeft(): tokenIds[](2);
 gasUsed = 56510
 gas_opde = 4
 base = 22k
 total = 56,510 + 4 + 22,000 = 78,514

#3: calc via gasLeft(): tokenIds[](3);
 gasUsed = 83082
 gas_opde = 4
 base = 22k
 total = 83,082 + 4 + 22,000 = 105,086

#4: calc via gasLeft(): tokenIds[](4);
 gasUsed = 109653
 gas_opde = 4
 base = 22k
 total = 109,653 + 4 + 22,000 = 131,657

#5: calc via gasLeft(): tokenIds[](5);
 gasUsed = 136226
 gas_opde = 4
 base = 22k
 total = 136,226 + 4 + 22,000 = 158,230




calculating via  --gas-report

 | Function Name                                     | min             | avg   | median | max   | # calls |
 | lzReceive                                         | 53915           | 54317 | 54503  | 54587 | 256     |

 */