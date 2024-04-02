// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {NftLocker} from "./../src/NftLocker.sol";
import {NftRegistry} from "./../src/NftRegistry.sol";
import "test/mocks/MockNft.sol";

import "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract LZState is Script {
    
    //Note: LZV2 testnet addresses

    uint16 public sepoliaID = 40161;
    address public sepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public mumbaiID = 40109;
    address public mumbaiEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public bnbID = 40102;
    address public bnbEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public arbSepoliaID = 40231;
    address public arbSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public opSepoliaID = 40232;
    address public opSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public baseSepoliaID = 40245;
    address public baseSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 homeChainID = sepoliaID;
    address homeLzEP = sepoliaEP;

    uint16 remoteChainID = arbSepoliaID;
    address remoteLzEP = arbSepoliaEP;

    // wallets
    address public wallet = 0xdE05a1Abb121113a33eeD248BD91ddC254d5E9Db;

    modifier broadcast() {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        _;

        vm.stopBroadcast();
    }
}

//Note: NftLocker 
contract DeployHome is LZState {
    
    function run() public broadcast {

        MockNft mockNft = new MockNft();
        mockNft.initialize("mocktNFT", "mocktNFT");

        address endpoint = homeLzEP;
        address owner = wallet;
        address mocaNftAddress = address(mockNft);

       NftLocker nftLocker = new NftLocker(endpoint, owner, mocaNftAddress, remoteChainID);
    }
}

// forge script script/DeployTest.s.sol:DeployHome --rpc-url sepolia --broadcast --verify -vvvv --etherscan-api-key sepolia

//Note: NftRegistry
contract DeployRemote is LZState {
    
    function run() public broadcast {

        address endpoint = remoteLzEP;
        address owner = wallet;
        address dummyPool = address(1);

        NftRegistry nftRegistry = new NftRegistry(endpoint, owner, dummyPool, homeChainID);
    }
}

// forge script script/DeployTest.s.sol:DeployRemote --rpc-url arbitrum_sepolia --broadcast --verify -vvvv --etherscan-api-key arbitrum_sepolia


abstract contract State is LZState {

    address public mockNftAddress = 0x54d4E6adc4f152ED4919C940CB3EA13B912519c9;
    address public nftLockerAddress = 0x18F786AE5Fb1639BAa4fcE4B8F29c783949a66A8;
    address public nftRegistryAddress = 0x03d9842E73b061AC6E20B7376fE3FEEDF55bc71a;

    MockNft public mockNft = MockNft(mockNftAddress);
    NftLocker public nftLocker = NftLocker(nftLockerAddress);
    NftRegistry public nftRegistry = NftRegistry(nftRegistryAddress);
 
}

// ------------------------------------------- Trusted Remotes: connect contracts -------------------------

contract SetRemoteOnHome is State {

    function run() public broadcast {

        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OApp contract to send msgs to
        bytes32 peer = bytes32(uint256(uint160(address(nftRegistry))));
        nftLocker.setPeer(remoteChainID, peer);
    }
}

// forge script script/DeployTest.s.sol:SetRemoteOnHome --rpc-url sepolia --broadcast -vvvv

contract SetRemoteOnAway is State {

    function run() public broadcast {
        
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OApp contract to send msgs to
        bytes32 peer = bytes32(uint256(uint160(address(nftLocker))));
        nftRegistry.setPeer(homeChainID, peer);
    }
}

// forge script script/DeployTest.s.sol:SetRemoteOnAway --rpc-url arbitrum_sepolia --broadcast -vvvv


// ------------------------------------------- Gas Limits -------------------------


import { IOAppOptionsType3, EnforcedOptionParam } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
//Note: OApp has no enforced options

/*
contract SetGasLimitsHome is State {

    function run() public broadcast {

        EnforcedOptionParam memory enforcedOptionParam;
        // msgType:1 -> a standard token transfer via send()
        // options: -> A typical lzReceive call will use 200000 gas on most EVM chains         
        EnforcedOptionParam[] memory enforcedOptionParams = new EnforcedOptionParam[](2);
        enforcedOptionParams[0] = EnforcedOptionParam(remoteChainID, 1, hex"00030100110100000000000000000000000000030d40");
        
        // block sendAndCall: createLzReceiveOption() set gas requirement to be 1M
        enforcedOptionParams[1] = EnforcedOptionParam(remoteChainID, 2, hex"000301001101000000000000000000000000000f4240");

        nftLocker.setEnforcedOptions(enforcedOptionParams);
    }
}

// forge script script/DeployTest.s.sol:SetGasLimitsHome --rpc-url sepolia --broadcast -vvvv


contract SetGasLimitsAway is State {

    function run() public broadcast {
        
        EnforcedOptionParam memory enforcedOptionParam;
        // msgType:1 -> a standard token transfer via send()
        // options: -> A typical lzReceive call will use 200000 gas on most EVM chains 
        EnforcedOptionParam[] memory enforcedOptionParams = new EnforcedOptionParam[](2);
        enforcedOptionParams[0] = EnforcedOptionParam(homeChainID, 1, hex"00030100110100000000000000000000000000030d40");
        
        // block sendAndCall: createLzReceiveOption() set gas requirement to be 1M
        enforcedOptionParams[1] = EnforcedOptionParam(homeChainID, 2, hex"000301001101000000000000000000000000000f4240");

        nftRegistry.setEnforcedOptions(enforcedOptionParams);
    }
}

// forge script script/DeployTest.s.sol:SetGasLimitsAway --rpc-url polygon_mumbai --broadcast -vvvv

*/

// ------------------------------------------- Mint and Lock an NFT -------------------------

contract LockNFT is State {

    function run() public broadcast {
        
        // mint + approve
        uint256 tokenId = 0;        
        mockNft.mint(tokenId);
        mockNft.setApprovalForAll(address(nftLocker), true);
        
        // array
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;


        // craft payload
        bytes memory payload = abi.encode(wallet, tokenIds);

        // options for locker_oneTokenId: 51_950 gas
        bytes memory options = hex"0003010011010000000000000000000000000000caee";
        
        (uint256 nativeFee, uint256 lzTokenFee) = nftLocker.quote(tokenIds);

        nftLocker.lock{value: nativeFee}(tokenIds);
    }
}

// forge script script/DeployTest.s.sol:LockNFT --rpc-url sepolia --broadcast -vvvv

contract ReleaseNFT is State {

    function run() public broadcast {
        
        uint256 tokenId = 0;

        // array
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // craft payload
        bytes memory payload = abi.encode(wallet, tokenIds);

        // options for registry_oneTokenId: 73_000 gas
        bytes memory options = hex"00030100110100000000000000000000000000011d28";
        
        (uint256 nativeFee, uint256 lzTokenFee) = nftRegistry.quote(tokenIds);

        nftRegistry.release{value: nativeFee}(tokenIds);
    }
}

// forge script script/DeployTest.s.sol:ReleaseNFT --rpc-url arbitrum_sepolia --broadcast -vvvv


// ------------------------------------------- Mint and Lock multiple NFTs -------------------------

contract LockNFTs is State {

    function run() public broadcast {
        
        // mint + approve
        mockNft.mint(1);
        mockNft.mint(2);
        mockNft.mint(3);
        mockNft.mint(4);
        mockNft.mint(5);
        mockNft.setApprovalForAll(address(nftLocker), true);
        
        // array
        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 1;
            tokenIds[1] = 2;
            tokenIds[2] = 3;
            tokenIds[3] = 4;
            tokenIds[4] = 5;


        // craft payload
        bytes memory payload = abi.encode(wallet, tokenIds);

        // options for locker_fiveTokenId: 158_350 gas
        bytes memory options = hex"00030100110100000000000000000000000000026a8e";
        
        (uint256 nativeFee, uint256 lzTokenFee) = nftLocker.quote(tokenIds);

        nftLocker.lock{value: nativeFee}(tokenIds);
    }
}

// forge script script/DeployTest.s.sol:LockNFTs --rpc-url sepolia --broadcast -vvvv

contract ReleaseNFTs is State {

    function run() public broadcast {
        
        // array
        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 1;
            tokenIds[1] = 2;
            tokenIds[2] = 3;
            tokenIds[3] = 4;
            tokenIds[4] = 5;

        // craft payload
        bytes memory payload = abi.encode(wallet, tokenIds);

        // options for registry_fiveTokenId: 146_612 gas
        bytes memory options = hex"00030100110100000000000000000000000000023cb4";
        
        (uint256 nativeFee, uint256 lzTokenFee) = nftRegistry.quote(tokenIds);

        nftRegistry.release{value: nativeFee}(tokenIds);
    }
}

// forge script script/DeployTest.s.sol:ReleaseNFTs --rpc-url arbitrum_sepolia --broadcast -vvvv
