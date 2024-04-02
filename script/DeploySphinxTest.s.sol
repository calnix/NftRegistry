// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Sphinx, Network} from "@sphinx-labs/contracts/SphinxPlugin.sol";

import {NftLocker} from "./../src/NftLocker.sol";
import {NftRegistry} from "./../src/NftRegistry.sol";
import "test/mocks/MockNft.sol";

import { IOAppOptionsType3, EnforcedOptionParam } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract LZState is Sphinx, Script {
    
    //Note: LZV2 testnet addresses

    uint16 public sepoliaID = 40161;
    address public sepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public mumbaiID = 40109;
    address public mumbaiEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public arbSepoliaID = 40231;
    address public arbSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 homeChainID = arbSepoliaID;
    address homeLzEP = arbSepoliaEP;

    uint16 remoteChainID = mumbaiID;
    address remoteLzEP = mumbaiEP;
    
    // block.chainid
    uint256 public blockChainId_mumbai = 80001;
    uint256 public blockChainId_sepolia = 11155111;
    uint256 public blockChainId_arbSepolia = 421614;
    
}

contract Deploy is LZState {

    NftLocker public locker;
    NftRegistry public registry;

    // Sphinx setup
    function configureSphinx() public override {
        sphinxConfig.owners = [address(0x5B7c596ef4804DC7802dB28618d353f7Bf14C619)]; // Add owner(s)
        sphinxConfig.orgId = "clu0e13bc0001t058dr9pubfl"; // Add Sphinx org ID
        
        sphinxConfig.testnets = ["arbitrum_sepolia", "polygon_mumbai"];

        sphinxConfig.projectName = "NftLockerV1";
        sphinxConfig.threshold = 1;
    }

    function run() public sphinx {

        // Home
        if (block.chainid == blockChainId_sepolia) {    

            // deploy mock nft
            MockNft mockNft = new MockNft();
            mockNft.initialize("mocktNFT", "mocktNFT");

            // params
            address endpoint = homeLzEP;
            address owner = safeAddress();          // use safe's addr
            address mocaNftAddress = address(mockNft);
            uint32 dstEid_ = remoteChainID;

            locker = new NftLocker(endpoint, owner, mocaNftAddress, dstEid_);
            
            vm.makePersistent(address(locker));

        // Remote  
        } else if (block.chainid == blockChainId_mumbai) { 
        
            address endpoint = remoteLzEP; 
            address owner = safeAddress();          // use safe's addr
            address dummyPool = address(1);
            uint32 dstEid_ = homeChainID;

            registry = new NftRegistry(endpoint, owner, dummyPool, dstEid_);

            vm.makePersistent(address(registry));
        }

        // Home
        if (block.chainid == blockChainId_sepolia) { 
        
            //............ Set peer on Home
            bytes32 peer = bytes32(uint256(uint160(address(registry))));
            locker.setPeer(remoteChainID, peer);

        // Remote
        } else if (block.chainid == blockChainId_mumbai) { 
            
            //............ Set peer on Remote
            bytes32 peer = bytes32(uint256(uint160(address(locker))));
            registry.setPeer(homeChainID, peer);
        }
    }
}


// npx sphinx propose script/DeploySphinxTest.s.sol --networks testnets
