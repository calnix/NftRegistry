// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { IOAppOptionsType3 } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

// issues
contract NftRegistry is OApp {

    address public pool;

    struct TokenData {
        address owner;
        bytes32 vaultId;         // non-zero value if staked
    }

    mapping(uint256 tokenId => TokenData data) public nfts;

    // events
    event PoolUpdated(address indexed newPool);
    event LockerUpdated(address indexed newLocker);

    event NftRegistered(address indexed user, uint256 indexed tokenId);
    event NftReleased(address indexed user, uint256 indexed tokenId);

    event NftStaked(address indexed user, uint256 indexed tokenId, bytes32 indexed vaultId);
    event NftUnstaked(address indexed user, uint256 indexed tokenId, bytes32 indexed vaultId);

//-------------------------------constructor-------------------------------------------
    constructor(address endpoint, address owner, address pool_) OApp(endpoint, owner) Ownable(owner) {
        pool = pool_;
    }

    /*//////////////////////////////////////////////////////////////
                                 LOCKER
    //////////////////////////////////////////////////////////////*/

    // only callable by _lzReceive
    //Note: if revert: storage must be modified by admin on Locker 
    function _register(address user, uint256[] memory tokenIds) internal {

        uint256 length = tokenIds.length;
        for (uint256 i; i < length; ++i) {

            uint256 tokenId = tokenIds[i];

            // cache
            TokenData memory data = nfts[tokenId];

            // ensure tokenId does not belong to someone else
            require(data.owner == address(0), "Already registered");

            // update storage
            data.owner = user;
            nfts[tokenId] = data;
            
            emit NftRegistered(user, tokenId);
        }
    }

    /** 
     * @notice Called by user to release unstaked NFTs on mainnet, by calling NftLocker
     * @dev Max array length is 5, and txn reverts if any of the tokenIds are still attached to a vault
     * @param tokenIds Destination chain's endpoint ID.
     * @param dstEid Destination chain's endpoint ID.
     * @param options Message execution options (e.g., gas to use on destination).
     */
    function release(uint256[] calldata tokenIds, uint32 dstEid, bytes calldata options) external payable {
        uint256 length = tokenIds.length;
        require(length <= 5, "Array max length exceeded");

        for (uint256 i; i < length; ++i) {

            uint256 tokenId = tokenIds[i];

            // cache
            TokenData memory data = nfts[tokenId];

            // check ownership + staking status
            require(data.owner == msg.sender, "Not Owner");
            require(data.vaultId == bytes32(0), "Nft is staked");
            
            // update storage
            delete nfts[tokenId];

            emit NftReleased(msg.sender, tokenId);
        }


        // craft payload
        bytes memory payload = abi.encode(msg.sender, tokenIds);

        // check gas needed
        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        require(msg.value >= fee.nativeFee, "Insufficient gas");

        // refund excess
        if(msg.value > fee.nativeFee) {
            uint256 excessGas = msg.value - fee.nativeFee;

            payable(msg.sender).transfer(excessGas);
            fee.nativeFee -= excessGas; 
        }

        _lzSend(dstEid, payload, options, fee, payable(msg.sender));

    }
    

//-------------------------------------------------------------------------------------

    /*//////////////////////////////////////////////////////////////
                                  POOL
    //////////////////////////////////////////////////////////////*/
   
    function setPool(address pool_) external onlyOwner {
        pool = pool_;
        emit PoolUpdated(pool_);
    }

    ///@dev only callable by pool
    function recordStake(address onBehalfOf, uint256 tokenId, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        // cache 
        TokenData memory data = nfts[tokenId];

        // ensure tokenId does not belong to someone else
        require(data.owner == onBehalfOf, "Incorrect tokenId");
        // ensure NFT has not been staked
        require(data.vaultId == bytes32(0), "Nft is staked");
        
        // update storage
        data.vaultId = vaultId;
        nfts[tokenId] = data;
        
        emit NftStaked(onBehalfOf, tokenId, vaultId);
    }

    ///@dev only callable by pool
    function recordUnstake(address onBehalfOf, uint256 tokenId, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        // cache 
        TokenData memory data = nfts[tokenId];

        // ensure tokenId does not belong to someone else
        require(data.owner == onBehalfOf, "Incorrect tokenId");
        // ensure correct vaultId
        require(data.vaultId == vaultId, "Incorrect vaultId");
        
        // update storage
        delete data.vaultId;
        nfts[tokenId] = data;
        
        emit NftUnstaked(onBehalfOf, tokenId, vaultId);
    }

//-------------------------------------------------------------------------------------


    /*//////////////////////////////////////////////////////////////
                               LAYERZERO
    //////////////////////////////////////////////////////////////*/

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param dstEid Destination chain's endpoint ID.
     * @param payload The message payload.
     * @param options Message execution options
     * @param payInLzToken boolean for which token to return fee in
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(uint32 dstEid, bytes calldata payload, bytes calldata options, bool payInLzToken) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        
        MessagingFee memory fee = _quote(dstEid, payload, options, payInLzToken);
        return (fee.nativeFee, fee.lzTokenFee);
    }


    /**
     * @dev Override of _lzReceive internal fn in OAppReceiver.sol. 
            The public fn lzReceive, handles param validation
     * @param payload message payload being received
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata payload, address, bytes calldata) internal override {
        
        // owner, tokendId
        (address owner, uint256[] memory tokenIds) = abi.decode(payload, (address, uint256[]));

        // update
        _register(owner, tokenIds);
    }


}

