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
import { OAppSender, Origin } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

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

        // userA has 1 nft: tokenId = 0
        uint256[] memory tokenIdsA = new uint256[](1);
        tokenIdsA[0] = 0;
        registry.register(userA, tokenIdsA);

        // userB has 1 nft: tokenId = 1,2
        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;
        registry.register(userB, tokenIdsB);

        // gas
        vm.deal(userA, 1 ether);
        vm.deal(userB, 1 ether);
    } 
}


contract StateZeroTest is StateZero {

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
        registry.setPool(userA);

        assertEq(registry.pool(), userA);
    }

    function testReleaseMaxArrayLimit() public {

        uint256[] memory tokenIds = new uint256[](10);
        
        vm.expectRevert("Array max length exceeded");
        registry.release{value: 1 ether}(tokenIds);
    }

    function testCannotReleaseRepeatedTokenIds() public {
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;        

        vm.expectRevert("Not Owner");
        registry.release{value: 91_403}(tokenIds);
    }

    function testCannotReleaseOtherTokenId() public {
        
        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;     

        vm.prank(userA);
        vm.expectRevert("Not Owner");
        registry.release{value: 91_403}(tokenIdsB);
    }

    function testReleaseRevertsInsufficientGas() public {
        
        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;     

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


        uint256[] memory tokenIdsB = new uint256[](2);
        tokenIdsB[0] = 1;
        tokenIdsB[1] = 2;

        vm.prank(userB);
        registry.release{value: 91_403}(tokenIdsB);

        // check mapping after
        (owner2, ) = registry.nfts(1);
        (owner3, ) = registry.nfts(2);

        assertEq(owner2, address(0));
        assertEq(owner3, address(0));
    }

    function testUserCannotRecordStake() public {
        
        vm.prank(userB);
        vm.expectRevert("Only pool");
        registry.recordStake(userB, 1, hex"01");
    }

    function testPoolCanRecordStake() public {
        
        vm.prank(dummyPool);
        registry.recordStake(userB, 1, hex"01");

        // check mapping
        (address owner, bytes32 vaultId) = registry.nfts(1);
        assertEq(vaultId, hex"01");
        assertEq(owner, userB);
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
     
    function testUserCannotRecordUnstake() public {
        
        vm.prank(userB);
        vm.expectRevert("Only pool");
        registry.recordUnstake(userB, 1, hex"01");
    }

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
        registry.release{value: 73_000}(tokenIds);
    }

    function testIncorrectUserRecordUnstake() public {
        vm.prank(dummyPool);
        vm.expectRevert("Incorrect tokenId");
        registry.recordUnstake(userA, 1, hex"01");
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