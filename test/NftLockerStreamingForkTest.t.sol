// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "./../src/NftLocker.sol";
import "./INftStreaming.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// mocks
import { MockNft } from "./mocks/MockNft.sol";
import { EndpointV2Mock } from "./mocks/EndpointV2Mock.sol";

// errors
import "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
// SendParam
import "@layerzerolabs/oft-evm/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OAppSender, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

abstract contract ForkMainnet is Test {

    // chain to fork
    uint256 public mainnetFork;   
    string public MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    // contracts to fork
    INftStreaming public nftStreaming;
    IERC20 public mocaToken;
    IERC721 public mocaNft;
    address public user = 0xF7CD1499aC017526Fa67D2B6659e24A6939fa09a;

    // local setup
    EndpointV2Mock public lzMock;
    NftLocker public nftLocker;
    address public owner;

    function setUp() public virtual {

        // fork
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
        
        nftStreaming = INftStreaming(0xb46F2634Fcb79fa2F73899487d04acfB0252A457);
        mocaToken = IERC20(0xF944e35f95E819E752f3cCB5Faf40957d311e8c5);
        mocaNft = IERC721(0x59325733eb952a92e069C87F0A6168b29E80627f);

        localSetup();
    }

    function localSetup() internal {
        owner = makeAddr("owner");
    
        uint32 dstEid = 1;

        vm.startPrank(owner);
            lzMock = new EndpointV2Mock();
            
            nftLocker = new NftLocker(address(lzMock), owner, address(mocaNft), dstEid);
            vm.label(address(nftLocker), "locker");

            nftLocker.setPeer(dstEid, bytes32(uint256(uint160(address(1)))));
        vm.stopPrank();
    }
}

//Note: Forking sanity checks
contract ForkMainnetTest is ForkMainnet {
    
    function testForkSelected() public {
        // confirm fork selected
        assertEq(vm.activeFork(), mainnetFork);
    }

    function testStreamingContractForked() public {
        // contract check
       assertEq(address(nftStreaming), 0xb46F2634Fcb79fa2F73899487d04acfB0252A457);
        
        /**
            ref txn: https://etherscan.io/tx/0x70cbbae02e03920271a7b8e7a9263bcc9ec82e44be567b5ee2c93470dc623f50

            In the above txn, msg.sender calls `claimSingle` on NftStreaming
            - tokenId: 4795
            - moca received: 783.111477184170106128
            - callerAddress: 0xF7CD1499aC017526Fa67D2B6659e24A6939fa09a
            - blockNumber: 22070239

            We verify our fork, by calling the view fn `claimable` after rolling back by 1 block
            - the outputs should match
            - output is an array of struct Delegation
            - array has only 1 member
        */  
        
        // nothing to claim since, he just claimed all oustanding as per txn
        vm.rollFork(22_070_239);  
        assertEq(block.number, 22_070_239);
        assertEq(nftStreaming.claimable(4795), 0);
        
        // rollback by 1 block
        vm.rollFork(22_070_239 - 1);  
        assertEq(block.number, 22_070_239 - 1);
        // rewards would be slightly lesser 
        uint256 claimable = nftStreaming.claimable(4795);
        assertEq(claimable, 783093381856925052864);
    }

    function testMocaForked() public {
        // ref txn: https://etherscan.io/tx/0x739f705d933d2571d9155369983bc32d9205941f4c018806897f28d5ae75e3ce

        // txn executed as per block 20771533
        vm.rollFork(22_070_239);  
        assertEq(block.number, 22_070_239);

        address owner = mocaNft.ownerOf(4795);
        
        // check new owner
        assertEq(owner, 0xF7CD1499aC017526Fa67D2B6659e24A6939fa09a);
    }

    function testLockNftIntoLocker() public {
        // check nft not locked before
        assertEq(nftLocker.nfts(4795), address(0));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4795;

        // deal
        vm.deal(user, 1 ether);

        // lock nft
        vm.startPrank(user);
            mocaNft.setApprovalForAll(address(nftLocker), true);
            nftLocker.lock{value: 51950}(tokenIds);
        vm.stopPrank();

        // check nft locked
        assertEq(nftLocker.nfts(4795), user);
    }
}

abstract contract LockNftIntoLocker is ForkMainnet {

    function setUp() public override {
        super.setUp();

        // fork 
        vm.rollFork(22_070_239 - 1);  
        assertEq(block.number, 22_070_239 - 1);

        // deal
        vm.deal(user, 1 ether);

        // lock nft
        vm.startPrank(user);
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = 4795;
            
            // set approval
            mocaNft.setApprovalForAll(address(nftLocker), true);
            // lock
            nftLocker.lock{value: 51950}(tokenIds);
        vm.stopPrank();

        vm.startPrank(nftStreaming.owner());
            nftStreaming.updateModule(address(nftLocker), true);
        vm.stopPrank();
    }
}


contract LockNftIntoLockerTest is LockNftIntoLocker {

    function test_ModuleEnabled() public {
        // check module enabled
        assertEq(nftStreaming.modules(address(nftLocker)), true);
    }

    function test_NftLocked_CanUserClaimStreamingRewards() public {
        // check nft locked
        assertEq(nftLocker.nfts(4795), user);
        // check claimable
        assertEq(nftStreaming.claimable(4795), 783093381856925052864);

        // check balance before
        uint256 balanceBefore = mocaToken.balanceOf(user);

        // check user can claim
        vm.startPrank(user);
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = 4795;
            nftStreaming.claimViaModule(address(nftLocker), tokenIds);
        vm.stopPrank();

        // check balance after
        uint256 balanceAfter = mocaToken.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, 783093381856925052864);

        // check claimable
        assertEq(nftStreaming.claimable(4795), 0);
    }

}
